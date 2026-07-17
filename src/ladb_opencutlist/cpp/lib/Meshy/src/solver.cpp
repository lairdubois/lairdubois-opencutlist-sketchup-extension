#include "solver.hpp"

#include "preprocessor.hpp"

#include <manifold/manifold.h>
#include <nlohmann/json.hpp>

#include <cstdint>
#include <fstream>
#include <istream>
#include <ostream>
#include <sstream>
#include <stdexcept>
#include <string>

namespace Meshy {

    using json = nlohmann::json;

    std::istream& operator>>(
            std::istream& in,
            Operation& operation)
    {
        std::string token;
        in >> token;
        if (token == "union") {
            operation = Operation::Union;
        } else if (token == "subtraction") {
            operation = Operation::Subtraction;
        } else if (token == "intersection") {
            operation = Operation::Intersection;
        } else  {
            in.setstate(std::ios_base::failbit);
        }
        return in;
    }

    std::ostream& operator<<(
            std::ostream &os,
            Operation operation)
    {
        switch (operation) {
            case Operation::Union: {
                os << "union";
                break;
            }
            case Operation::Subtraction: {
                os << "subtraction";
                break;
            }
            case Operation::Intersection: {
                os << "intersection";
                break;
            }
        }
        return os;
    }

    namespace {

        void read_mesh(
                const json& j,
                manifold::MeshGL64& mesh
        ) {

            // Vertices
            const auto& verts = j.at("vertices");
            if (verts.size() % 3 != 0) {
                throw std::runtime_error("'vertices' must contain a multiple of 3 values");
            }

            mesh.vertProperties.resize(verts.size());
            for (std::size_t i = 0; i < verts.size(); ++i) {
                mesh.vertProperties[i] = verts[i].get<double>();
            }

            mesh.numProp = 3; // x, y, z

            // Triangles
            const auto& tris = j.at("face_indices");
            if (tris.size() % 3 != 0) {
                throw std::runtime_error("'face_indices' must contain a multiple of 3 indices");
            }

            mesh.triVerts.resize(tris.size());
            for (std::size_t i = 0; i < tris.size(); ++i) {
                mesh.triVerts[i] = tris[i].get<uint32_t>();
            }

            // Tolerance
            // Geometric features smaller than this are considered coincident : lets the
            // boolean absorb near-coplanar faces instead of leaving sliver residues.
            if (j.contains("tolerance")) {
                mesh.tolerance = j.at("tolerance").get<double>();
            }

            // FaceIds
            if (j.contains("face_ids")) {
                const auto& ids = j.at("face_ids");

                mesh.faceID.resize(ids.size());
                for (std::size_t i = 0; i < ids.size(); ++i) {
                    mesh.faceID[i] = ids[i].get<uint32_t>();
                }
            }

        }

        // Writes one fragment from the shells of ONE body : its outer surface
        // first, then the inner shells of its internal voids (inward wound),
        // merged into a single indexed mesh so hollow bodies survive the JSON
        // round-trip.
        void write_fragment(
                json& j,
                const std::vector<manifold::MeshGL64>& meshes
        ) {

            j["vertices"] = json::array();
            j["face_indices"] = json::array();
            j["face_ids"] = json::array();

            std::size_t vertex_offset = 0;
            std::size_t face_count = 0;
            for (const auto& mesh : meshes) {

                // Vertices
                const std::size_t stride = mesh.numProp;
                const std::size_t vertex_count = mesh.vertProperties.size() / stride;
                for (std::size_t v = 0; v < vertex_count; ++v) {
                    j["vertices"].push_back(mesh.vertProperties[v * stride]);
                    j["vertices"].push_back(mesh.vertProperties[v * stride + 1]);
                    j["vertices"].push_back(mesh.vertProperties[v * stride + 2]);
                }

                // Triangles
                for (uint32_t idx : mesh.triVerts) {
                    j["face_indices"].push_back(idx + vertex_offset);
                }

                // FaceID
                for (uint32_t id : mesh.faceID) {
                    j["face_ids"].push_back(id);
                }

                vertex_offset += vertex_count;
                face_count += mesh.triVerts.size() / 3;
            }

            j["num_vertices"] = vertex_offset;
            j["num_faces"] = face_count;

        }

    }

    Solver Solver::build(
            const std::string& filepath
    ) {

        std::ifstream ifs(filepath);
        if (!ifs.good()) {
            throw std::runtime_error("Unable to open file path \"" + filepath + "\".");
        }

        return build(ifs);
    }

    Solver Solver::build(
            std::istream& is
    ) {

        json j;
        is >> j;

        Solver solver;
        solver.read(j);

        return solver;
    }

    void Solver::read(
            const json& j
    ) {

        if (j.contains("operation")) {
            std::stringstream ss(j.value("operation", "union"));
            ss >> operation_;
        }

        if (j.contains("validate")) {
            validate_ = j.at("validate").get<bool>();
        }

        if (j.contains("tolerance")) {
            tolerance_ = j.at("tolerance").get<double>();
        }

        if (j.contains("src_meshes")) {
            for (auto& j_item: j["src_meshes"].items()) {
                auto& j_item_value = j_item.value();
                read_mesh(j_item_value, src_meshes_.emplace_back());
            }
        }

        if (j.contains("cut_meshes")) {
            for (auto& j_item: j["cut_meshes"].items()) {
                auto& j_item_value = j_item.value();
                read_mesh(j_item_value, cut_meshes_.emplace_back());
            }
        }

    }

    json Solver::operate() {

        // Validation : structured errors, one at most per mesh, src meshes first.

        if (validate_) {
            json j_errors = json::array();
            auto fn_append_errors = [&j_errors](const manifold::MeshGL64& mesh) {
                for (const auto& error : validate_mesh(mesh)) {
                    json j_error;
                    j_error["code"] = error.code;
                    if (error.count > 0) {
                        j_error["count"] = error.count;
                    }
                    j_errors.push_back(j_error);
                }
            };
            for (auto& mesh : src_meshes_) fn_append_errors(mesh);
            for (auto& mesh : cut_meshes_) fn_append_errors(mesh);
            if (!j_errors.empty()) {
                json output;
                output["errors"] = j_errors;
                return output;
            }
        }

        // Manifold interprets winding as defining solidity : make sure normals point outward.

        for (auto& mesh : src_meshes_) ensure_outward_winding(mesh);
        for (auto& mesh : cut_meshes_) ensure_outward_winding(mesh);

        // Snap every vertex of every operand onto a canonical plane set built from all
        // their faces : each face becomes exactly planar, and faces meant to be coplanar
        // (or edges/vertices meant to lie on a face of the other operand) become exactly
        // so. Otherwise, the boolean would leave epsilon-thin residues (closed cavities,
        // slivers) between nearly coincident geometry.

        std::vector<manifold::MeshGL64*> all_meshes;
        all_meshes.reserve(src_meshes_.size() + cut_meshes_.size());
        for (auto& mesh : src_meshes_) all_meshes.push_back(&mesh);
        for (auto& mesh : cut_meshes_) all_meshes.push_back(&mesh);

        const std::vector<Plane> planes = canonical_planes(all_meshes, tolerance_);
        for (auto* mesh : all_meshes) snap_to_planes(*mesh, planes, tolerance_);

        // Exact coplanarity is only achievable in doubles on the exact-axis planes :
        // on a tilted plane, snapped vertices keep ~1e-15 inconsistent residues that
        // Manifold's exact arithmetic resolves into epsilon-thin residues (closed
        // pockets under the surviving face, sliver flaps along the seams). So every
        // tilted plane shared by two operands that get booleaned together has the
        // coincidence broken into a CLEAR transversal configuration by nudging
        // vertices along the plane normal. Each nudged operand receives its own
        // offset multiple ((rank + 1) x SHARED_PLANE_OFFSET), so no two operands
        // stay tied with each other on the plane either — this is what makes the
        // result independent of the operand order. Then the nudged meshes are
        // re-snapped onto the axis planes the nudge may have dragged them off.
        //
        // - Union merges everything : every operand with a face on a shared tilted
        //   plane is expanded across it along its own outward normal, so seams
        //   become robust overlaps.
        // - Subtraction / intersection : the cuts are chained together first, then
        //   applied to each src. A plane shared with a src face keeps the historic
        //   intent — all cuts are pushed toward the src exterior (the cut cleanly
        //   swallows or stops at the src face). A plane shared between cuts only is
        //   handled like the union case (their chaining is a union) — except for
        //   intersection, whose cut chaining shrinks, so cuts contract instead.

        {
            std::vector<manifold::MeshGL64*> nudge_pool;
            if (operation_ == Operation::Union) {
                nudge_pool = all_meshes;
            } else {
                for (auto& mesh : cut_meshes_) nudge_pool.push_back(&mesh);
            }

            // The offsets are first COLLECTED per operand, then applied in a
            // single per-vertex simultaneous solve : a vertex at a corner
            // where several nudged planes meet must honor all its offsets at
            // once — see nudge_vertices_to_offset_planes.
            std::vector<std::vector<std::pair<const Plane*, double>>> pool_offsets(nudge_pool.size());
            for (const auto& plane : planes) {
                if (is_axis_plane(plane)) continue;

                std::vector<double> pool_signs(nudge_pool.size());
                std::size_t faces_on_plane = 0;
                for (std::size_t k = 0; k < nudge_pool.size(); ++k) {
                    pool_signs[k] = outward_sign_on_plane(*nudge_pool[k], plane, tolerance_);
                    if (pool_signs[k] != 0.0) ++faces_on_plane;
                }

                double src_sign = 0.0;
                if (operation_ != Operation::Union) {
                    for (auto& mesh : src_meshes_) {
                        src_sign = outward_sign_on_plane(mesh, plane, tolerance_);
                        if (src_sign != 0.0) break;
                    }
                }

                if (src_sign != 0.0 && faces_on_plane > 0) {
                    // src face on the plane : every cut (even one only touching the
                    // plane through an edge or vertex) moves to the src exterior.
                    for (std::size_t k = 0; k < nudge_pool.size(); ++k) {
                        pool_offsets[k].emplace_back(&plane, src_sign * SHARED_PLANE_OFFSET * double(k + 1));
                    }
                } else if (faces_on_plane >= 2) {
                    // plane shared between chained operands only : expand each face
                    // across it (contract for intersection chaining).
                    const double dir = (operation_ == Operation::Intersection ? -1.0 : 1.0);
                    for (std::size_t k = 0; k < nudge_pool.size(); ++k) {
                        if (pool_signs[k] == 0.0) continue;
                        pool_offsets[k].emplace_back(&plane, dir * pool_signs[k] * SHARED_PLANE_OFFSET * double(k + 1));
                    }
                }
            }
            bool nudged = false;
            for (std::size_t k = 0; k < nudge_pool.size(); ++k) {
                if (pool_offsets[k].empty()) continue;
                nudge_vertices_to_offset_planes(*nudge_pool[k], pool_offsets[k], tolerance_);
                nudged = true;
            }
            if (nudged) {
                std::vector<Plane> axis_planes;
                for (const auto& plane : planes) {
                    if (is_axis_plane(plane)) axis_planes.push_back(plane);
                }
                if (!axis_planes.empty()) {
                    for (auto* mesh : nudge_pool) snap_to_planes(*mesh, axis_planes, tolerance_);
                }
            }
        }

        // Build Manifolds

        std::vector<manifold::Manifold> src_manifolds;
        for (auto& mesh : src_meshes_) {
            manifold::Manifold& manifold = src_manifolds.emplace_back(mesh);
            if (manifold.Status() != manifold::Manifold::Error::NoError) {
                throw std::runtime_error("Mesh is not a valid manifold");
            }
        }

        std::vector<manifold::Manifold> cut_manifolds;
        for (auto& mesh : cut_meshes_) {
            manifold::Manifold& manifold = cut_manifolds.emplace_back(mesh);
            if (manifold.Status() != manifold::Manifold::Error::NoError) {
                throw std::runtime_error("Mesh is not a valid manifold");
            }
        }

        // Boolean operations
        //
        // Subtraction and intersection are applied to EACH src independently
        // (against the cuts combined) : srcs are never merged together, so
        // touching or overlapping srcs keep their own identity and every
        // result body is attributable to a single src. Union is the one
        // operation whose purpose is to merge : it stays global.

        std::vector<manifold::Manifold> results;
        switch (operation_) {
            case Operation::Union: {
                manifold::Manifold result;
                for (auto& manifold : cut_manifolds) {
                    result = result + manifold;
                }
                for (auto& manifold : src_manifolds) {
                    result = result + manifold;
                }
                results.push_back(result);
                break;
            }
            case Operation::Subtraction: {
                manifold::Manifold cut_result;
                for (auto& manifold : cut_manifolds) {
                    cut_result = cut_result + manifold;
                }
                for (auto& manifold : src_manifolds) {
                    results.push_back(manifold - cut_result);
                }
                break;
            }
            case Operation::Intersection: {
                // The cuts are chained together first. The default-constructed
                // manifold is empty and would absorb the whole intersection :
                // keep track of whether a cut seeded it, so an empty cut list
                // leaves each src unchanged.
                manifold::Manifold cut_result;
                bool has_cut = false;
                for (auto& manifold : cut_manifolds) {
                    if (has_cut) {
                        cut_result ^= manifold;
                    } else {
                        cut_result = manifold;
                        has_cut = true;
                    }
                }
                for (auto& manifold : src_manifolds) {
                    results.push_back(has_cut ? manifold ^ cut_result : manifold);
                }
                break;
            }
        }

        // --- export ---

        // One fragment per topologically disconnected body, so the caller can
        // reattribute each of them to its source mesh through face provenance.
        // Simplify() collapses degenerate leftovers (slivers thinner than the
        // tolerance inherited from the input meshes) ; like Decompose(), it
        // maintains the mesh relation, so input face provenance (faceID) that
        // the Ruby side uses to restore materials and merge triangles back
        // into faces is preserved. Do NOT call AsOriginal() here.
        // Decompose() is purely topological : the inner shell of a hollow body
        // (a closed internal void) comes out as its own component, wound inward
        // and thus of NEGATIVE volume. Each of them is reattached to the body
        // whose bounding box contains it (the smallest such body when nested)
        // and exported inside the same fragment, so hollow bodies survive the
        // JSON round-trip instead of coming back filled.
        // Exactly coplanar face-to-face contact (axis planes, no nudge) resolves,
        // for intersection, into closed zero-volume membranes that Simplify()
        // keeps (their triangles are not degenerate). A body or a void below the
        // volume of a tolerance-sized cube cannot exist in SketchUp : drop it.
        const double min_volume = tolerance_ * tolerance_ * tolerance_;

        json output;
        output["fragments"] = json::array();
        for (auto& result : results) {
            if (result.Status() != manifold::Manifold::Error::NoError) {
                throw std::runtime_error("Boolean operation failed");
            }

            std::vector<manifold::Manifold> bodies;
            std::vector<manifold::Manifold> voids;
            for (auto& part : result.Simplify().Decompose()) {
                const double volume = part.Volume();
                if (volume > min_volume) {
                    bodies.push_back(part);
                } else if (volume < -min_volume) {
                    voids.push_back(part);
                }
            }

            std::vector<std::vector<manifold::MeshGL64>> fragment_meshes(bodies.size());
            std::vector<manifold::Box> body_boxes;
            std::vector<double> body_volumes;
            body_boxes.reserve(bodies.size());
            body_volumes.reserve(bodies.size());
            for (std::size_t i = 0; i < bodies.size(); ++i) {
                fragment_meshes[i].push_back(bodies[i].GetMeshGL64());
                body_boxes.push_back(bodies[i].BoundingBox());
                body_volumes.push_back(bodies[i].Volume());
            }

            for (auto& void_part : voids) {
                const manifold::Box void_box = void_part.BoundingBox();
                std::ptrdiff_t container = -1;
                for (std::size_t i = 0; i < bodies.size(); ++i) {
                    if (!body_boxes[i].Contains(void_box)) continue;
                    if (container < 0 || body_volumes[i] < body_volumes[container]) container = i;
                }
                // An orphan void (no containing body) has nothing to hollow : dropped.
                if (container >= 0) fragment_meshes[container].push_back(void_part.GetMeshGL64());
            }

            for (const auto& meshes : fragment_meshes) {
                write_fragment(output["fragments"].emplace_back(), meshes);
            }
        }

        return output;
    }

}