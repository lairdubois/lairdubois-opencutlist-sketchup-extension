#pragma once

#include <manifold/manifold.h>

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <string>
#include <unordered_map>
#include <utility>
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

    // A pinch (non-manifold edge or vertex) joins two or more manifold sheets
    // at a set of measure zero (shared vertices only, no shared volume) : e.g.
    // a picture-frame part whose ring width shrinks to exactly zero at one
    // corner (touching itself there) is, apart from that single defect, one
    // ordinary connected shell all the way around — NOT two disjoint shells
    // touching at a point. So the fix cannot be "find disjoint components and
    // duplicate what they share" : the two sides of the pinch are typically
    // still connected to each other through the rest of the mesh. What must
    // be duplicated is narrower and purely local : at the pinched EDGE, the
    // faces fanned around it split into two or more locally-manifold sheets ;
    // at the pinched VERTEX (which usually also anchors faces that never
    // touch the pinched edge itself, e.g. the top/bottom faces of the frame,
    // triangulated straight across both sides of the corner), the full ring
    // of incident triangles splits into two or more "umbrellas" separated by
    // the pinched edges. Each sheet / umbrella gets its own copy of the
    // vertices it touches there ; coordinates are never changed.
    //
    // Manifold accepts the result : Impl::IsManifold()
    // (manifold/src/properties.cpp) is a purely local, per-halfedge check
    // with no global connectivity requirement, so one MeshGL64 buffer whose
    // seams have been unzipped this way is valid input whether or not the
    // resulting shells end up disjoint or still joined elsewhere (a
    // picture-frame part stays ONE connected genus-1 shell after the fix,
    // exactly as it should).
    //
    // Algorithm :
    //  1. For every non-manifold edge (an undirected edge used by other than
    //     one forward + one backward triangle occurrence), sort its incident
    //     triangles angularly around the edge axis (by the position of each
    //     triangle's third vertex). Complementary winding direction alone
    //     is NOT enough to pick the pairing : for the common case of two
    //     wedges touching (4 occurrences), winding simply alternates all the
    //     way around regardless of which sectors are actually solid, so
    //     BOTH ways of pairing angularly-adjacent occurrences pass a
    //     direction-only test. What actually resolves it is which angular
    //     sector, between two consecutive rays, is solid material : each
    //     occurrence's outward face normal (consistently outward once
    //     ensure_outward_winding has run) is perpendicular to its own ray
    //     and necessarily points into whichever of its two neighboring
    //     sectors is EMPTY, so it tells us, per ray, which side is solid.
    //     Two angularly-adjacent rays are paired when both agree the sector
    //     between them is solid ; solid and empty sectors strictly
    //     alternate around a clean touch, so every ray ends up claimed by
    //     exactly one pair. A genuine self-intersection (surfaces crossing,
    //     not touching) has no self-consistent solid/empty alternation this
    //     way and is refused rather than guessed at (verified directly, not
    //     just by direction parity, which the symmetric case above shows
    //     is not sufficient by itself).
    //  2. For every vertex touched by at least one non-manifold edge, replay
    //     that pairing (plus ordinary 1-forward/1-backward clean edges) as
    //     adjacency between its incident triangles, and take connected
    //     components : each component is one umbrella. A vertex with a
    //     single umbrella needs no duplicate ; others get one extra vertex
    //     (identical coordinates) per additional umbrella.
    //  3. Remap every triangle corner to the duplicate of its umbrella.
    //
    // Returns false — mesh left untouched — when the defect isn't a clean
    // touch this way : a genuinely open/leaky mesh (an edge used only once),
    // an edge whose valence is odd, or incident triangles whose directions
    // can't be paired into complementary sheets (an actual self-intersection,
    // not a touch). The result is always re-validated before being accepted,
    // so a bug in this function can only ever fall back to the original
    // error, never emit a silently-wrong repair.
    inline bool split_non_manifold_shells(
            manifold::MeshGL64& mesh
    ) {
        const std::size_t tri_count = mesh.triVerts.size() / 3;
        if (tri_count == 0) return true;

        const std::size_t stride = mesh.numProp;
        auto vertex_pos = [&](uint64_t v) {
            return &mesh.vertProperties[v * stride];
        };

        auto edge_key = [](uint64_t a, uint64_t b) { return (a << 32) | b; };
        auto undirected_key = [&](uint64_t a, uint64_t b) { return a < b ? edge_key(a, b) : edge_key(b, a); };

        struct Occurrence { std::size_t triangle; uint64_t a, b; };
        std::unordered_map<uint64_t, std::vector<Occurrence>> occurrences_by_edge;
        occurrences_by_edge.reserve(tri_count * 3);
        for (std::size_t t = 0; t < tri_count; ++t) {
            const uint64_t v[3] = { mesh.triVerts[t * 3], mesh.triVerts[t * 3 + 1], mesh.triVerts[t * 3 + 2] };
            for (int e = 0; e < 3; ++e) {
                const uint64_t a = v[e], b = v[(e + 1) % 3];
                occurrences_by_edge[undirected_key(a, b)].push_back({ t, a, b });
            }
        }

        // Resolve every edge into the pairs of triangles that are genuinely
        // adjacent across it (fan-adjacency). Clean edges pair trivially;
        // non-manifold edges are resolved by angular sort around the edge
        // axis. keyed by the SAME undirected key as occurrences_by_edge.
        std::unordered_map<uint64_t, std::vector<std::pair<std::size_t, std::size_t>>> fan_pairs;
        fan_pairs.reserve(occurrences_by_edge.size());

        for (auto& entry : occurrences_by_edge) {
            const uint64_t key = entry.first;
            std::vector<Occurrence>& occs = entry.second; // Named ref, not a structured binding : lambdas below capture it by reference, which structured bindings cannot do until C++20.
            if (occs.size() == 2 && occs[0].a != occs[1].a) {
                fan_pairs[key].emplace_back(occs[0].triangle, occs[1].triangle);
                continue;
            }
            if (occs.size() < 2 || occs.size() % 2 != 0) return false; // Open edge, or odd valence : not a clean touch.

            const uint64_t a = occs[0].a, b = occs[0].b;
            const double* pa = vertex_pos(a);
            const double* pb = vertex_pos(b);
            double d[3] = { pb[0] - pa[0], pb[1] - pa[1], pb[2] - pa[2] };
            const double dlen = std::sqrt(d[0]*d[0] + d[1]*d[1] + d[2]*d[2]);
            if (dlen == 0.0) return false;
            for (double& c : d) c /= dlen;

            // Per-occurrence radial vector (edge axis to the triangle's third
            // vertex, direction component removed) and its angle in an
            // arbitrary basis (e1, e2) perpendicular to the edge.
            const std::size_t n = occs.size();
            std::vector<double> radial(n * 3);
            for (std::size_t i = 0; i < n; ++i) {
                const uint64_t tv[3] = {
                    mesh.triVerts[occs[i].triangle * 3],
                    mesh.triVerts[occs[i].triangle * 3 + 1],
                    mesh.triVerts[occs[i].triangle * 3 + 2]
                };
                uint64_t w = tv[0];
                for (uint64_t cand : tv) { if (cand != a && cand != b) { w = cand; break; } }
                const double* pw = vertex_pos(w);
                double rw[3] = { pw[0] - pa[0], pw[1] - pa[1], pw[2] - pa[2] };
                const double proj = rw[0]*d[0] + rw[1]*d[1] + rw[2]*d[2];
                for (int c = 0; c < 3; ++c) radial[i*3 + c] = rw[c] - proj * d[c];
            }

            double e1[3] = { radial[0], radial[1], radial[2] };
            double e1len = std::sqrt(e1[0]*e1[0] + e1[1]*e1[1] + e1[2]*e1[2]);
            if (e1len == 0.0) return false; // Third vertex sits on the edge line : degenerate triangle.
            for (double& c : e1) c /= e1len;
            double e2[3] = { d[1]*e1[2] - d[2]*e1[1], d[2]*e1[0] - d[0]*e1[2], d[0]*e1[1] - d[1]*e1[0] };

            std::vector<std::size_t> order(n);
            std::vector<double> angle(n);
            for (std::size_t i = 0; i < n; ++i) {
                const double x = radial[i*3]*e1[0] + radial[i*3+1]*e1[1] + radial[i*3+2]*e1[2];
                const double y = radial[i*3]*e2[0] + radial[i*3+1]*e2[1] + radial[i*3+2]*e2[2];
                if (x == 0.0 && y == 0.0) return false; // Third vertex on the edge line.
                angle[i] = std::atan2(y, x);
                order[i] = i;
            }
            std::sort(order.begin(), order.end(), [&](std::size_t x, std::size_t y) { return angle[x] < angle[y]; });

            // Direction-complementarity alone is ambiguous : for the common
            // case of exactly two wedges of material touching along the edge
            // (4 occurrences), BOTH ways of pairing angularly-adjacent
            // occurrences satisfy it — winding direction simply alternates
            // around the whole fan regardless of which sectors are actually
            // solid. What resolves it is which angular sector, between two
            // consecutive rays, is material : each occurrence's outward
            // face normal (consistently outward once ensure_outward_winding
            // has run) is perpendicular to its own ray and necessarily
            // points into whichever of its two neighboring sectors is EMPTY
            // — so it tells us, per ray, which side is solid. A sector is
            // solid when both rays bounding it agree on that, and the two
            // rays bounding a solid sector are exactly the pair that closes
            // it into a manifold edge there. Sectors alternate solid/empty
            // strictly by construction, so every ray ends up claimed by
            // exactly one solid sector. A genuine self-intersection (surfaces
            // crossing, not touching) has no self-consistent solid/empty
            // alternation this way, so it is refused rather than guessed at
            // — this is also what makes the resolution unambiguous where
            // pure direction-parity was not.
            std::vector<bool> solid_follows(n); // Sector strictly after this ray (CCW) is solid.
            for (std::size_t i = 0; i < n; ++i) {
                const std::size_t t = occs[i].triangle;
                const double* p0 = vertex_pos(mesh.triVerts[t * 3]);
                const double* p1 = vertex_pos(mesh.triVerts[t * 3 + 1]);
                const double* p2 = vertex_pos(mesh.triVerts[t * 3 + 2]);
                const double nx = (p1[1]-p0[1])*(p2[2]-p0[2]) - (p1[2]-p0[2])*(p2[1]-p0[1]);
                const double ny = (p1[2]-p0[2])*(p2[0]-p0[0]) - (p1[0]-p0[0])*(p2[2]-p0[2]);
                const double nz = (p1[0]-p0[0])*(p2[1]-p0[1]) - (p1[1]-p0[1])*(p2[0]-p0[0]);
                const double nx1 = nx*e1[0] + ny*e1[1] + nz*e1[2];
                const double ny1 = nx*e2[0] + ny*e2[1] + nz*e2[2];

                const double rx = radial[i*3]*e1[0] + radial[i*3+1]*e1[1] + radial[i*3+2]*e1[2];
                const double ry = radial[i*3]*e2[0] + radial[i*3+1]*e2[1] + radial[i*3+2]*e2[2];
                const double rlen = std::sqrt(rx*rx + ry*ry);
                const double cross_z = (rx/rlen) * ny1 - (ry/rlen) * nx1;
                if (cross_z == 0.0) return false; // Normal parallel to the ray : degenerate.
                solid_follows[i] = cross_z < 0.0;
            }

            std::vector<std::pair<std::size_t, std::size_t>> candidate;
            for (std::size_t i = 0; i < n; ++i) {
                const std::size_t cur = order[i];
                const std::size_t nxt = order[(i + 1) % n];
                const bool sector_solid_by_cur = solid_follows[cur];
                const bool sector_solid_by_nxt = !solid_follows[nxt]; // nxt's "preceding" sector is this one.
                if (sector_solid_by_cur != sector_solid_by_nxt) return false; // Inconsistent : not a clean touch.
                if (!sector_solid_by_cur) continue; // Empty sector : the two rays are not adjacent across material.
                if (occs[cur].a == occs[nxt].a) return false; // Defensive : must also be direction-complementary.
                candidate.emplace_back(occs[cur].triangle, occs[nxt].triangle);
            }
            if (candidate.size() != n / 2) return false; // Every ray must be claimed by exactly one solid sector.

            fan_pairs[key] = std::move(candidate);
        }

        // Vertex -> incident undirected edge keys, so each vertex's umbrella
        // can be computed from the fan_pairs of just its own edges.
        std::unordered_map<uint64_t, std::vector<uint64_t>> vertex_edges;
        for (auto& [key, occs] : occurrences_by_edge) {
            vertex_edges[occs[0].a].push_back(key);
            vertex_edges[occs[0].b].push_back(key);
        }

        const std::size_t original_vertex_count = mesh.vertProperties.size() / stride;
        std::vector<std::unordered_map<std::size_t, uint64_t>> remap_by_vertex(original_vertex_count);
        // Only vertices touched by a resolved non-manifold edge can possibly need
        // more than one umbrella; skip the rest.
        std::vector<bool> needs_check(original_vertex_count, false);
        for (auto& [key, occs] : occurrences_by_edge) {
            if (occs.size() == 2 && occs[0].a != occs[1].a) continue;
            needs_check[occs[0].a] = true;
            needs_check[occs[0].b] = true;
        }

        for (uint64_t v = 0; v < original_vertex_count; ++v) {
            if (!needs_check[v]) continue;
            const auto vit = vertex_edges.find(v);
            if (vit == vertex_edges.end()) continue;

            // Local union-find over v's incident triangles.
            std::unordered_map<std::size_t, std::size_t> local_index;
            std::vector<std::size_t> triangles;
            for (uint64_t key : vit->second) {
                for (auto& [t1, t2] : fan_pairs[key]) {
                    for (std::size_t t : { t1, t2 }) {
                        if (local_index.try_emplace(t, triangles.size()).second) triangles.push_back(t);
                    }
                }
            }
            std::vector<std::size_t> parent(triangles.size());
            for (std::size_t i = 0; i < parent.size(); ++i) parent[i] = i;
            auto find = [&](std::size_t x) {
                while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; }
                return x;
            };
            for (uint64_t key : vit->second) {
                for (auto& [t1, t2] : fan_pairs[key]) {
                    const std::size_t x = find(local_index[t1]);
                    const std::size_t y = find(local_index[t2]);
                    if (x != y) parent[x] = y;
                }
            }

            std::unordered_map<std::size_t, uint64_t> umbrella_vertex; // root -> assigned vertex index
            auto& remap = remap_by_vertex[v];
            for (std::size_t i = 0; i < triangles.size(); ++i) {
                const std::size_t root = find(i);
                const auto it = umbrella_vertex.find(root);
                uint64_t assigned;
                if (it == umbrella_vertex.end()) {
                    assigned = umbrella_vertex.empty() ? v : mesh.vertProperties.size() / stride;
                    if (assigned != v) {
                        for (std::size_t p = 0; p < stride; ++p) {
                            mesh.vertProperties.push_back(mesh.vertProperties[v * stride + p]);
                        }
                    }
                    umbrella_vertex[root] = assigned;
                } else {
                    assigned = it->second;
                }
                remap[triangles[i]] = assigned;
            }
        }

        for (std::size_t t = 0; t < tri_count; ++t) {
            for (int k = 0; k < 3; ++k) {
                const std::size_t v = mesh.triVerts[t * 3 + k];
                if (v >= remap_by_vertex.size()) continue; // Never a duplicated original vertex.
                const auto it = remap_by_vertex[v].find(t);
                if (it != remap_by_vertex[v].end()) mesh.triVerts[t * 3 + k] = it->second;
            }
        }

        return validate_mesh(mesh).empty();
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
    // tolerance) on one or more of the target planes clears EACH of them by
    // the requested signed offset. The displacement is solved per
    // vertex over all its planes simultaneously (incremental
    // orthonormalization + forward substitution, planes taken in the given
    // order — offsets first, then the zero-offset holds, each in canonical
    // order, largest faces first — and capped at 3 independent constraints) :
    // shifting sequentially along each plane normal, as a per-plane pass
    // would, breaks the previously applied offsets at every corner where
    // target planes meet — the later shift has a component along the earlier
    // normal — and can land the vertex on the WRONG side of a plane it was
    // meant to clear, leaving an epsilon crossing that the boolean turns into
    // slivers, in a way that depends on the operand order.
    //
    // An offset is a MINIMUM clearance, not an exact target : a vertex the
    // constraints accepted before it have already carried past the requested
    // distance is left where it is, rather than pulled back onto the offset
    // plane. Overshooting is always safe — the operands are being expanded
    // apart, and a wider clearance only makes the configuration more clearly
    // transversal — whereas pulling back makes the FINAL position of a vertex
    // depend on which other planes happen to pass through it, so two operands
    // meeting at an edge through DIFFERENT planes ended up recessed relative
    // to one another by an amount decided by their offset multiples, i.e. by
    // the operand order. A zero offset is the one exact constraint : it holds
    // the vertex ON its plane (see the axis planes in Solver::operate).
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

                // n·δ = Σ proj[j]·a[j] + rl·a[count] must reach offset - dist
                double partial = 0.0;
                for (int j = 0; j < count; ++j) partial += proj[j] * a[j];

                // Minimum clearance : nothing to impose when the constraints
                // accepted so far already carry the vertex past it. Skipping
                // rather than solving also leaves the slot free for the next
                // plane.
                const double target = offset - dist;
                if (offset > 0.0 && partial >= target) continue;
                if (offset < 0.0 && partial <= target) continue;

                e[count][0] = rx / rl;
                e[count][1] = ry / rl;
                e[count][2] = rz / rl;
                a[count] = (target - partial) / rl;
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