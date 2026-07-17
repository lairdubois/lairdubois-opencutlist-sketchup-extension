#pragma once

#include <manifold/manifold.h>

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>

namespace Meshy {

    // Geometric preprocessing of the boolean operands.
    //
    // Manifold's exact arithmetic sees any near-coincidence between operands
    // (~1e-15 rounding residues) as real crossing surfaces and produces
    // epsilon-thin residues (closed cavities, slivers). The preprocessing makes
    // coincidences EXACT where doubles allow it (snapping every vertex onto a
    // canonical plane set) and CLEARLY transversal where exactness is not
    // achievable (nudging the cut operands along tilted shared planes).

    // Plane n·p = d with unit normal, weighted by the squared area of the
    // triangle it was computed from.
    struct Plane {
        double nx, ny, nz, d;
        double area2;
    };

    struct ValidationError {
        std::string code;
        std::size_t count;
    };

    // Offset applied to cut vertices lying on a tilted plane shared with a src face :
    // far above snapping residues (~1e-14), far below SketchUp tolerance (1e-3),
    // so the perturbation is invisible in the rebuilt geometry.
    constexpr double SHARED_PLANE_OFFSET = 1e-6;

    // True if the plane is one of the exact axis-aligned planes produced by
    // weighted_face_planes' normal quantization.
    inline bool is_axis_plane(
            const Plane& plane
    ) {
        return (plane.nx == 1.0 && plane.ny == 0.0 && plane.nz == 0.0)
            || (plane.nx == 0.0 && plane.ny == 1.0 && plane.nz == 0.0)
            || (plane.nx == 0.0 && plane.ny == 0.0 && plane.nz == 1.0);
    }

    // Returns at most one error. Empty if the mesh is a valid closed solid: a
    // watertight, consistently oriented triangle mesh has every directed edge
    // appearing exactly once, paired with its reverse.
    inline std::vector<ValidationError> validate_mesh(
            const manifold::MeshGL64& mesh
    ) {
        std::vector<ValidationError> errors;

        if (mesh.triVerts.empty()) {
            errors.push_back({ "empty", 0 });
            return errors;
        }

        // Directed edge (a, b) packed into a single key. SketchUp meshes stay far
        // below 2^32 vertices, so the packing is collision-free.
        auto edge_key = [](uint64_t a, uint64_t b) { return (a << 32) | b; };

        std::unordered_map<uint64_t, uint32_t> directed_edges;
        for (std::size_t t = 0; t + 2 < mesh.triVerts.size(); t += 3) {
            const uint64_t i0 = mesh.triVerts[t];
            const uint64_t i1 = mesh.triVerts[t + 1];
            const uint64_t i2 = mesh.triVerts[t + 2];
            ++directed_edges[edge_key(i0, i1)];
            ++directed_edges[edge_key(i1, i2)];
            ++directed_edges[edge_key(i2, i0)];
        }

        std::size_t duplicated_count = 0;
        for (const auto& [key, count] : directed_edges) {
            if (count > 1) ++duplicated_count;
        }
        if (duplicated_count > 0) {
            errors.push_back({ "non_manifold_edges", duplicated_count });
            return errors;
        }

        std::size_t open_count = 0;
        for (const auto& [key, count] : directed_edges) {
            const uint64_t reverse_key = edge_key(key & 0xffffffffull, key >> 32);
            if (directed_edges.find(reverse_key) == directed_edges.end()) ++open_count;
        }
        if (open_count > 0) {
            errors.push_back({ "open_edges", open_count });
        }

        return errors;
    }

    // Signed volume (positive if triangles are consistently wound with outward normals).
    inline double signed_volume(
            const manifold::MeshGL64& mesh
    ) {
        const std::size_t stride = mesh.numProp;
        double volume = 0.0;
        for (std::size_t t = 0; t + 2 < mesh.triVerts.size(); t += 3) {
            const double* p0 = &mesh.vertProperties[mesh.triVerts[t] * stride];
            const double* p1 = &mesh.vertProperties[mesh.triVerts[t + 1] * stride];
            const double* p2 = &mesh.vertProperties[mesh.triVerts[t + 2] * stride];
            volume += p0[0] * (p1[1] * p2[2] - p2[1] * p1[2])
                    - p0[1] * (p1[0] * p2[2] - p2[0] * p1[2])
                    + p0[2] * (p1[0] * p2[1] - p2[0] * p1[1]);
        }
        return volume / 6.0;
    }

    // Manifold interprets winding as defining solidity : flip the triangles if
    // normals point inward. faceID is per-triangle, so it stays aligned.
    inline void ensure_outward_winding(
            manifold::MeshGL64& mesh
    ) {
        if (signed_volume(mesh) >= 0.0) return;
        for (std::size_t t = 0; t + 2 < mesh.triVerts.size(); t += 3) {
            std::swap(mesh.triVerts[t + 1], mesh.triVerts[t + 2]);
        }
    }

    // Returns one plane per original face (grouped by faceID, or per triangle if
    // faceID is absent), computed from the largest triangle of the face for
    // numerical stability, weighted by that triangle's squared area.
    // The normal is canonically oriented (first significant component positive) so
    // that opposite-facing coplanar faces yield comparable planes.
    //
    // Triangles whose minimum altitude is below the tolerance never seed a
    // plane : geometry that thin cannot exist in SketchUp, so such a triangle
    // is a boolean artifact of a previous operation (e.g. the micro step strip
    // a staggered nudge leaves at a joint when its output is fed back in, as
    // the cavity worker does), whose arbitrary normal would pollute the
    // canonical plane set — and, the artifacts depending on the original
    // operand order, leak that order into the result.
    inline std::vector<Plane> weighted_face_planes(
            const manifold::MeshGL64& mesh,
            double tolerance
    ) {
        const std::size_t stride = mesh.numProp;

        std::vector<Plane> planes;
        std::unordered_map<uint64_t, std::size_t> plane_index_by_face_id;

        for (std::size_t t = 0; t + 2 < mesh.triVerts.size(); t += 3) {
            const std::size_t triangle_index = t / 3;

            const double* p0 = &mesh.vertProperties[mesh.triVerts[t] * stride];
            const double* p1 = &mesh.vertProperties[mesh.triVerts[t + 1] * stride];
            const double* p2 = &mesh.vertProperties[mesh.triVerts[t + 2] * stride];

            double nx = (p1[1] - p0[1]) * (p2[2] - p0[2]) - (p1[2] - p0[2]) * (p2[1] - p0[1]);
            double ny = (p1[2] - p0[2]) * (p2[0] - p0[0]) - (p1[0] - p0[0]) * (p2[2] - p0[2]);
            double nz = (p1[0] - p0[0]) * (p2[1] - p0[1]) - (p1[1] - p0[1]) * (p2[0] - p0[0]);
            const double area2 = nx * nx + ny * ny + nz * nz;
            if (area2 == 0.0) continue;

            // Minimum altitude = 2 * area / longest edge, squared : area2 is
            // (2 * area)^2, so altitude^2 = area2 / longest_edge2.
            double longest_edge2 = 0.0;
            for (int e = 0; e < 3; ++e) {
                const double* a = e == 0 ? p0 : (e == 1 ? p1 : p2);
                const double* b = e == 0 ? p1 : (e == 1 ? p2 : p0);
                const double ex = b[0] - a[0], ey = b[1] - a[1], ez = b[2] - a[2];
                longest_edge2 = std::max(longest_edge2, ex * ex + ey * ey + ez * ez);
            }
            if (area2 < tolerance * tolerance * longest_edge2) continue;

            const uint64_t face_id = mesh.faceID.empty() ? triangle_index : mesh.faceID[triangle_index];
            const auto it = plane_index_by_face_id.find(face_id);
            if (it != plane_index_by_face_id.end() && planes[it->second].area2 >= area2) continue;

            const double length = std::sqrt(area2);
            nx /= length;
            ny /= length;
            nz /= length;
            if (nx < -1e-9 || (std::abs(nx) <= 1e-9 && (ny < -1e-9 || (std::abs(ny) <= 1e-9 && nz < 0.0)))) {
                nx = -nx;
                ny = -ny;
                nz = -nz;
            }

            // Snap near-axis normals to the exact axis direction. Projection onto an exact
            // axis plane assigns the exact same coordinate (d) to every projected vertex of
            // every operand, achieving true exact coplanarity. A projection onto a plane
            // tilted by ~1e-16 (numerical noise of the source triangle) would leave ~1e-15
            // off-plane rounding residues, which Manifold's exact arithmetic still sees as
            // crossing surfaces, producing epsilon-thin residues.
            if (std::abs(ny) <= 1e-9 && std::abs(nz) <= 1e-9) {
                nx = 1.0; ny = 0.0; nz = 0.0;
            } else if (std::abs(nx) <= 1e-9 && std::abs(nz) <= 1e-9) {
                nx = 0.0; ny = 1.0; nz = 0.0;
            } else if (std::abs(nx) <= 1e-9 && std::abs(ny) <= 1e-9) {
                nx = 0.0; ny = 0.0; nz = 1.0;
            }

            const Plane plane = { nx, ny, nz, nx * p0[0] + ny * p0[1] + nz * p0[2], area2 };
            if (it != plane_index_by_face_id.end()) {
                planes[it->second] = plane;
            } else {
                plane_index_by_face_id[face_id] = planes.size();
                planes.push_back(plane);
            }
        }

        return planes;
    }

    // Builds a deduplicated plane set from all the given meshes : planes that are
    // identical within tolerance are represented once, by the instance backed by the
    // largest triangle. Snapping EVERY vertex of EVERY operand onto this canonical
    // set makes each face exactly planar and faces meant to be coplanar between
    // operands exactly coplanar.
    inline std::vector<Plane> canonical_planes(
            const std::vector<manifold::MeshGL64*>& meshes,
            double tolerance
    ) {
        std::vector<Plane> all;
        for (const auto* mesh : meshes) {
            const std::vector<Plane> planes = weighted_face_planes(*mesh, tolerance);
            all.insert(all.end(), planes.begin(), planes.end());
        }

        // Ties are broken on the plane coefficients (not on input order), so the
        // canonical set does not depend on the order the operands were given in.
        std::stable_sort(all.begin(), all.end(), [](const Plane& a, const Plane& b) {
            if (a.area2 != b.area2) return a.area2 > b.area2;
            if (a.nx != b.nx) return a.nx < b.nx;
            if (a.ny != b.ny) return a.ny < b.ny;
            if (a.nz != b.nz) return a.nz < b.nz;
            return a.d < b.d;
        });

        std::vector<Plane> canonical;
        for (const auto& plane : all) {
            const bool merged = std::any_of(canonical.begin(), canonical.end(), [&](const Plane& c) {
                return plane.nx * c.nx + plane.ny * c.ny + plane.nz * c.nz > 1.0 - 1e-8
                    && std::abs(plane.d - c.d) <= tolerance;
            });
            if (!merged) canonical.push_back(plane);
        }
        return canonical;
    }

    // Projects every vertex closer than tolerance to one of the given planes onto it,
    // so that faces meant to be coplanar with the other operand become EXACTLY coplanar.
    // Iterated a few times so that vertices near several planes (shared edges, corners)
    // converge to the planes intersection.
    inline void snap_to_planes(
            manifold::MeshGL64& mesh,
            const std::vector<Plane>& planes,
            double tolerance
    ) {
        if (planes.empty() || mesh.triVerts.empty()) return;

        // Project onto non-axis planes first and exact-axis planes last : axis planes are
        // orthogonal to each other, so late axis projections do not disturb one another
        // and the vertex ends EXACTLY on every nearby axis plane (the only exactness
        // achievable in doubles, and the one coplanarity snapping relies on). A tilted
        // plane projected last would drag the vertex ~1e-14 off the axis planes.
        std::vector<const Plane*> ordered;
        ordered.reserve(planes.size());
        for (const auto& plane : planes) {
            if (!is_axis_plane(plane)) ordered.push_back(&plane);
        }
        for (const auto& plane : planes) {
            if (is_axis_plane(plane)) ordered.push_back(&plane);
        }

        const std::size_t stride = mesh.numProp;
        const std::size_t vertex_count = mesh.vertProperties.size() / stride;
        for (std::size_t v = 0; v < vertex_count; ++v) {
            double& x = mesh.vertProperties[v * stride];
            double& y = mesh.vertProperties[v * stride + 1];
            double& z = mesh.vertProperties[v * stride + 2];
            for (int iteration = 0; iteration < 3; ++iteration) {
                for (const auto* plane : ordered) {
                    const double dist = x * plane->nx + y * plane->ny + z * plane->nz - plane->d;
                    if (dist == 0.0 || std::abs(dist) > tolerance) continue;
                    x -= dist * plane->nx;
                    y -= dist * plane->ny;
                    z -= dist * plane->nz;
                }
            }
        }
    }

    // If the mesh has at least one triangle lying on the given plane (its three
    // vertices within tolerance), returns +1.0 / -1.0 : the sign of the outward
    // normal of those triangles against the plane normal (area weighted).
    // Returns 0.0 if no triangle lies on the plane.
    inline double outward_sign_on_plane(
            const manifold::MeshGL64& mesh,
            const Plane& plane,
            double tolerance
    ) {
        const std::size_t stride = mesh.numProp;
        const std::size_t vertex_count = mesh.vertProperties.size() / stride;

        std::vector<double> distances(vertex_count);
        for (std::size_t v = 0; v < vertex_count; ++v) {
            distances[v] = mesh.vertProperties[v * stride] * plane.nx
                         + mesh.vertProperties[v * stride + 1] * plane.ny
                         + mesh.vertProperties[v * stride + 2] * plane.nz
                         - plane.d;
        }

        double sum = 0.0;
        for (std::size_t t = 0; t + 2 < mesh.triVerts.size(); t += 3) {
            const uint64_t i0 = mesh.triVerts[t];
            const uint64_t i1 = mesh.triVerts[t + 1];
            const uint64_t i2 = mesh.triVerts[t + 2];
            if (std::abs(distances[i0]) > tolerance
                || std::abs(distances[i1]) > tolerance
                || std::abs(distances[i2]) > tolerance) continue;
            const double* p0 = &mesh.vertProperties[i0 * stride];
            const double* p1 = &mesh.vertProperties[i1 * stride];
            const double* p2 = &mesh.vertProperties[i2 * stride];
            const double nx = (p1[1] - p0[1]) * (p2[2] - p0[2]) - (p1[2] - p0[2]) * (p2[1] - p0[1]);
            const double ny = (p1[2] - p0[2]) * (p2[0] - p0[0]) - (p1[0] - p0[0]) * (p2[2] - p0[2]);
            const double nz = (p1[0] - p0[0]) * (p2[1] - p0[1]) - (p1[1] - p0[1]) * (p2[0] - p0[0]);
            sum += nx * plane.nx + ny * plane.ny + nz * plane.nz;
        }

        if (sum == 0.0) return 0.0;
        return sum > 0.0 ? 1.0 : -1.0;
    }

    // A nudge constraint is dropped when its normal leaves less than this
    // squared residual against the span of the constraints already honored on
    // the vertex (nearly dependent planes) : bounds the solve amplification to
    // 1/sqrt(min) = 10, keeping the displacement orders of magnitude below the
    // tolerance.
    constexpr double NUDGE_CONDITION_MIN = 1e-2;

    // Displaces the mesh vertices so that every vertex lying (within
    // tolerance) on one or more of the target planes ends EXACTLY at the
    // requested signed offset from EACH of them. The displacement is solved
    // per vertex over all its planes simultaneously (incremental
    // orthonormalization + forward substitution, planes taken in the given
    // order — canonical order, largest faces first — and capped at 3
    // independent constraints) : shifting sequentially along each plane
    // normal, as a per-plane pass would, breaks the previously applied
    // offsets at every corner where target planes meet — the later shift has
    // a component along the earlier normal — and can land the vertex on the
    // WRONG side of a plane it was meant to clear, leaving an epsilon
    // crossing that the boolean turns into slivers, in a way that depends on
    // the operand order.
    inline void nudge_vertices_to_offset_planes(
            manifold::MeshGL64& mesh,
            const std::vector<std::pair<const Plane*, double>>& plane_offsets,
            double tolerance
    ) {
        if (plane_offsets.empty() || mesh.triVerts.empty()) return;

        const std::size_t stride = mesh.numProp;
        const std::size_t vertex_count = mesh.vertProperties.size() / stride;
        for (std::size_t v = 0; v < vertex_count; ++v) {
            double& x = mesh.vertProperties[v * stride];
            double& y = mesh.vertProperties[v * stride + 1];
            double& z = mesh.vertProperties[v * stride + 2];

            // Orthonormal basis of the accepted constraint normals, and the
            // displacement coefficients over it.
            double e[3][3];
            double a[3];
            int count = 0;

            for (const auto& [plane, offset] : plane_offsets) {
                if (count == 3) break;
                const double dist = x * plane->nx + y * plane->ny + z * plane->nz - plane->d;
                if (std::abs(dist) > tolerance) continue;

                // Component of the plane normal orthogonal to the accepted basis
                double rx = plane->nx, ry = plane->ny, rz = plane->nz;
                double proj[3];
                for (int j = 0; j < count; ++j) {
                    proj[j] = plane->nx * e[j][0] + plane->ny * e[j][1] + plane->nz * e[j][2];
                    rx -= proj[j] * e[j][0];
                    ry -= proj[j] * e[j][1];
                    rz -= proj[j] * e[j][2];
                }
                const double r2 = rx * rx + ry * ry + rz * rz;
                if (r2 < NUDGE_CONDITION_MIN) continue;
                const double rl = std::sqrt(r2);

                // n·δ = Σ proj[j]·a[j] + rl·a[count] must equal offset - dist
                double partial = 0.0;
                for (int j = 0; j < count; ++j) partial += proj[j] * a[j];
                e[count][0] = rx / rl;
                e[count][1] = ry / rl;
                e[count][2] = rz / rl;
                a[count] = (offset - dist - partial) / rl;
                ++count;
            }

            for (int j = 0; j < count; ++j) {
                x += a[j] * e[j][0];
                y += a[j] * e[j][1];
                z += a[j] * e[j][2];
            }
        }
    }

}