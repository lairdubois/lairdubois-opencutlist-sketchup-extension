#pragma once

#include <manifold/manifold.h>
#include <nlohmann/json.hpp>

#include <cstdint>
#include <istream>
#include <memory>
#include <ostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace Meshy {

    using json = nlohmann::json;

    enum class SolverType
    {
        Manifold,
    };

    inline std::istream& operator>>(
            std::istream& in,
            SolverType& solver_type)
    {
        std::string token;
        in >> token;
        if (token == "manifold") {
            solver_type = SolverType::Manifold;
        } else  {
            in.setstate(std::ios_base::failbit);
        }
        return in;
    }

    inline std::ostream& operator<<(
            std::ostream &os,
            SolverType solver_type)
    {
        switch (solver_type) {
            case SolverType::Manifold: {
                os << "manifold";
                break;
            }
        }
        return os;
    }

    enum class Operation
    {
        Union,
        Subtraction,
        Intersection,
    };

    inline std::istream& operator>>(
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

    inline std::ostream& operator<<(
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

    class Solver {

    public:

        /** Constructor. */
        Solver() = default;

        /** Destructor. */
        virtual ~Solver() = default;

        virtual void read(
            const json& j
        ) {

            if (j.contains("operation")) {
                std::stringstream ss(j.value("operation", "union"));
                ss >> operation_;
            }

        };

        virtual json operate() = 0;

    protected:

        Operation operation_ = Operation::Union;

    };

    typedef std::shared_ptr<Solver> SolverPtr;

    class ManifoldSolver : public Solver {

    public:

        void read(
            const json& j
        ) override {
            Solver::read(j);

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

        json operate() override {
            json j;

            // Build Manifolds

            std::vector<manifold::Manifold> src_manifolds;
            for (auto& mesh : src_meshes_) {
                manifold::Manifold& manifold = src_manifolds.emplace_back(mesh);
                if (manifold.Status() != manifold::Manifold::Error::NoError) {
                    throw std::runtime_error("mesh n'est pas un manifold valide");
                }
            }

            std::vector<manifold::Manifold> cut_manifolds;
            for (auto& mesh : cut_meshes_) {
                manifold::Manifold& manifold = cut_manifolds.emplace_back(mesh);
                if (manifold.Status() != manifold::Manifold::Error::NoError) {
                    throw std::runtime_error("mesh n'est pas un manifold valide");
                }
            }

            // Boolean operations

            manifold::Manifold result;
            switch (operation_) {
                case Operation::Union:
                    for (auto& manifold : cut_manifolds) {
                        result = result + manifold;
                    }
                    for (auto& manifold : src_manifolds) {
                        result = result + manifold;
                    }
                    break;
                case Operation::Subtraction: {
                    manifold::Manifold cut_result;
                    for (auto& manifold : cut_manifolds) {
                        cut_result = cut_result + manifold;
                    }
                    manifold::Manifold src_result;
                    for (auto& manifold : src_manifolds) {
                        src_result = src_result + manifold;
                    }
                    result = src_result - cut_result;
                    break;
                }
                case Operation::Intersection: {
                    // The default-constructed manifold is empty and would absorb the
                    // whole intersection: seed result with the first operand, whichever
                    // list it comes from, so empty lists are harmless (result stays empty).
                    bool first = true;
                    for (auto& manifold : cut_manifolds) {
                        if (first) {
                            result = manifold;
                            first = false;
                        } else {
                            result ^= manifold;
                        }
                    }
                    for (auto& manifold : src_manifolds) {
                        if (first) {
                            result = manifold;
                            first = false;
                        } else {
                            result ^= manifold;
                        }
                    }
                    break;
                }
            }

            if (result.Status() != manifold::Manifold::Error::NoError) {
                throw std::runtime_error("L'opération a échouée");
            }

            // Collapse degenerate leftovers (slivers thinner than the tolerance
            // inherited from the input meshes). Unlike AsOriginal(), Simplify()
            // maintains the mesh relation, so input face provenance (faceID) that
            // the Ruby side uses to restore materials and merge triangles back
            // into faces is preserved. Do NOT call AsOriginal() here.
            result = result.Simplify();

            // --- export ---
            manifold::MeshGL64 result_mesh = result.GetMeshGL64();

            json output;
            write_mesh(output["fragments"].emplace_back(), result_mesh);

            return output;
        }

        static void read_mesh(
            const json& j,
            manifold::MeshGL64& mesh
        ) {

            // Vertices
            const auto& verts = j.at("vertices");
            if (verts.size() % 3 != 0) {
                throw std::runtime_error("'vertices' doit contenir un multiple de 3 valeurs");
            }

            mesh.vertProperties.resize(verts.size());
            for (std::size_t i = 0; i < verts.size(); ++i) {
                mesh.vertProperties[i] = verts[i].get<double>();
            }

            mesh.numProp = 3; // x, y, z

            // Triangles
            const auto& tris = j.at("face_indices");
            if (tris.size() % 3 != 0) {
                throw std::runtime_error("'face_indices' doit contenir un multiple de 3 indices");
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

        static void write_mesh(
            json& j,
            const manifold::MeshGL64& mesh
        ) {

            // Vertices
            j["vertices"] = json::array();
            for (auto v : mesh.vertProperties) {
                j["vertices"].push_back(v);
            }

            // Triangles
            j["face_indices"] = json::array();
            for (uint32_t idx : mesh.triVerts) {
                j["face_indices"].push_back(idx);
            }

            // FaceID
            j["face_ids"] = json::array();
            for (uint32_t id : mesh.faceID) {
                j["face_ids"].push_back(id);
            }

            j["num_vertices"] = mesh.vertProperties.size() / mesh.numProp;
            j["num_faces"] = mesh.triVerts.size() / 3;

        }

    private:

        std::vector<manifold::MeshGL64> src_meshes_;
        std::vector<manifold::MeshGL64> cut_meshes_;

    };

}
