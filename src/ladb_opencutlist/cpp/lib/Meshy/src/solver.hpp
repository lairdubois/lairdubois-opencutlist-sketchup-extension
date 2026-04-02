#pragma once

#include <mcut/mcut.h>
#include <manifold/manifold.h>
#include <nlohmann/json.hpp>

#include <iostream>
#include <sstream>

#define my_assert(cond)                          \
    if(!(cond)) {                                \
        throw std::runtime_error("MCUT error");  \
    }

using namespace nlohmann;

namespace Meshy {

    enum class SolverType
    {
        MCut,
        Manifold,
    };

    inline std::istream& operator>>(
            std::istream& in,
            SolverType& solver_type)
    {
        std::string token;
        in >> token;
        if (token == "mcut") {
            solver_type = SolverType::MCut;
        } else if (token == "manifold") {
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
            case SolverType::MCut: {
                os << "mcut";
                break;
            }
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

    struct Mesh {
        std::vector<McDouble> vertices;
        std::vector<McUint32> face_indices;
        std::vector<McUint32> face_sizes;
        McUint32              num_vertices = 0;
        McUint32              num_faces    = 0;
    };

    class Solver {

    public:

        /** Constructor. */
        Solver() = default;

        /** Destructor. */
        virtual ~Solver() = default;

        virtual void read(
            basic_json<>& j
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

    class MCutSolver : public Solver {

    public:

        /*
         * Read:
         */

        void read(
            basic_json<>& j
        ) override {
            Solver::read(j);

            if (j.contains("src_mesh")) {
                read_mesh(j["src_mesh"], src_mesh_);
            }

            if (j.contains("cut_mesh")) {
                read_mesh(j["cut_mesh"], cut_mesh_);
            }

        }

        static bool read_mesh(
            const basic_json<>& j,
            Mesh& mesh
        ) {
            try {
                if (!j.contains("vertices") || !j["vertices"].is_array()) return false;
                if (!j.contains("face_indices") || !j["face_indices"].is_array()) return false;
                if (!j.contains("face_sizes") || !j["face_sizes"].is_array()) return false;
                if (!j.contains("num_vertices") || !j["num_vertices"].is_number_unsigned()) return false;
                if (!j.contains("num_faces") || !j["num_faces"].is_number_unsigned()) return false;

                mesh.vertices = j.at("vertices").get<std::vector<McDouble>>();
                mesh.face_indices = j.at("face_indices").get<std::vector<McUint32>>();
                mesh.face_sizes = j.at("face_sizes").get<std::vector<McUint32>>();
                mesh.num_vertices = j.at("num_vertices").get<McUint32>();
                mesh.num_faces = j.at("num_faces").get<McUint32>();

                if (mesh.num_vertices != mesh.vertices.size()) return false;
                if (mesh.num_faces != mesh.face_sizes.size()) return false;

                std::size_t total_face_indices = 0;
                for (McUint32 s : mesh.face_sizes) {
                    total_face_indices += s;
                }
                if (total_face_indices != mesh.face_indices.size()) return false;

                return true;
            } catch (const std::exception&) {
                return false;
            }
        }

        static bool write_mesh(
            const Mesh& mesh,
            McConnectedComponentType type,
            std::vector<McDouble>& perturbation_vector,
            basic_json<>& j
        ) {
            try {
                j["type"] = type;
                j["perturbation_vector"] = perturbation_vector;
                j["vertices"] = mesh.vertices;
                j["face_indices"] = mesh.face_indices;
                j["face_sizes"] = mesh.face_sizes;
                j["num_vertices"] = mesh.num_vertices;
                j["num_faces"] = mesh.num_faces;
                return true;
            } catch (const std::exception&) {
                return false;
            }
        }

        /*
         * Operate:
         */

        json operate() override {
            json j;

            // Create a context
            // ----------------

            McContext context = MC_NULL_HANDLE;
            McResult status = mcCreateContext(&context, MC_NULL_HANDLE);
            my_assert (status == MC_NO_ERROR);

            // Do the cutting
            // --------------

            status = mcDispatch(
                context,
                MC_DISPATCH_VERTEX_ARRAY_DOUBLE
                | MC_DISPATCH_ENFORCE_GENERAL_POSITION
                | MC_DISPATCH_INCLUDE_INTERSECTION_TYPE,

                src_mesh_.vertices.data(),
                src_mesh_.face_indices.data(),
                src_mesh_.face_sizes.data(),
                src_mesh_.num_vertices,
                src_mesh_.num_faces,

                cut_mesh_.vertices.data(),
                cut_mesh_.face_indices.data(),
                cut_mesh_.face_sizes.data(),
                cut_mesh_.num_vertices,
                cut_mesh_.num_faces

            );
            my_assert (status == MC_NO_ERROR);

            // Get fragments
            // -------------

            McUint32 num_connected_components;
            std::vector<McConnectedComponent> connected_components;

            status = mcGetConnectedComponents(context, MC_CONNECTED_COMPONENT_TYPE_ALL, 0, nullptr, &num_connected_components);
            my_assert (status == MC_NO_ERROR);

            connected_components.resize(num_connected_components); // Allocate for the amount we want to get

            status = mcGetConnectedComponents(context, MC_CONNECTED_COMPONENT_TYPE_ALL, (McUint32)connected_components.size(), connected_components.data(), nullptr);
            my_assert (status == MC_NO_ERROR);

            // Query the data of each connected component
            // ------------------------------------------

            for (auto cc : connected_components) {

                // Connected component id
                McSize num_bytes = 0;

                Mesh mesh;

                // type

                McConnectedComponentType type;

                status = mcGetConnectedComponentData(context, cc, MC_CONNECTED_COMPONENT_DATA_TYPE, 0, nullptr, &num_bytes);
                my_assert (status == MC_NO_ERROR);

                status = mcGetConnectedComponentData(context, cc, MC_CONNECTED_COMPONENT_DATA_TYPE, 0, &type, nullptr);
                my_assert (status == MC_NO_ERROR);

                //

                num_bytes = 0;

                status = mcGetConnectedComponentData(context, cc, MC_CONNECTED_COMPONENT_DATA_DISPATCH_PERTURBATION_VECTOR, 0, nullptr, &num_bytes);
                my_assert (status == MC_NO_ERROR);

                std::vector<McDouble> perturbation_vector(num_bytes / sizeof(McDouble));

                status = mcGetConnectedComponentData(context, cc, MC_CONNECTED_COMPONENT_DATA_DISPATCH_PERTURBATION_VECTOR, 0, perturbation_vector.data(), nullptr);
                my_assert (status == MC_NO_ERROR);

                // vertices

                num_bytes = 0;

                status = mcGetConnectedComponentData(context, cc, MC_CONNECTED_COMPONENT_DATA_VERTEX_DOUBLE, 0, nullptr, &num_bytes);
                my_assert (status == MC_NO_ERROR);

                mesh.num_vertices = static_cast<McUint32>(num_bytes / (sizeof(McDouble) * 3ull));
                mesh.vertices.resize(mesh.num_vertices * 3u);

                status = mcGetConnectedComponentData(context, cc, MC_CONNECTED_COMPONENT_DATA_VERTEX_DOUBLE, num_bytes, mesh.vertices.data(), nullptr);
                my_assert (status == MC_NO_ERROR);

                // faces

                num_bytes = 0;

                status = mcGetConnectedComponentData(context, cc, MC_CONNECTED_COMPONENT_DATA_FACE, 0, nullptr, &num_bytes);
                my_assert (status == MC_NO_ERROR);

                mesh.face_indices.resize(num_bytes / sizeof(McUint32));

                status = mcGetConnectedComponentData(context, cc, MC_CONNECTED_COMPONENT_DATA_FACE, num_bytes, mesh.face_indices.data(), nullptr);
                my_assert (status == MC_NO_ERROR);

                // face sizes (vertices per face)

                num_bytes = 0;

                status = mcGetConnectedComponentData(context, cc, MC_CONNECTED_COMPONENT_DATA_FACE_SIZE, 0, nullptr, &num_bytes);
                my_assert (status == MC_NO_ERROR);

                mesh.face_sizes.resize(num_bytes / sizeof(McUint32));

                status = mcGetConnectedComponentData(context, cc, MC_CONNECTED_COMPONENT_DATA_FACE_SIZE, num_bytes, (McVoid*)mesh.face_sizes.data(), nullptr);
                my_assert (status == MC_NO_ERROR);

                mesh.num_faces = static_cast<McUint32>(mesh.face_sizes.size());

                // Write mesh
                write_mesh(mesh, type, perturbation_vector, j["fragments"].emplace_back());

            }

            // Free memory of _all_ connected components (could also free them individually inside above for-loop)
            // ---------------------------------------------------------------------------------------------------

            status = mcReleaseConnectedComponents(context, 0, nullptr);
            my_assert (status == MC_NO_ERROR);

            // free memory of context
            // ----------------------

            status = mcReleaseContext(context);
            my_assert (status == MC_NO_ERROR);

            return std::move(j);
        }

    private:

        Mesh src_mesh_;
        Mesh cut_mesh_;

    };

    class ManifoldSolver : public Solver {

    public:

        void read(
            basic_json<>& j
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
                case Operation::Intersection:
                    result = cut_manifolds[0];
                    for (std::size_t i = 1; i < cut_manifolds.size(); ++i) {
                        result ^= cut_manifolds[i];
                    }
                    for (auto& manifold : src_manifolds) {
                        result ^= manifold;
                    }
                    break;
            }

            if (result.Status() != manifold::Manifold::Error::NoError) {
                throw std::runtime_error("L'opération a échouée");
            }

            result = result.AsOriginal();

            double tolerence = result.GetTolerance();
            result = result.Simplify(tolerence);

            // --- export ---
            manifold::MeshGL64 result_mesh = result.GetMeshGL64();

            json output;
            write_mesh(output["fragments"].emplace_back(), result_mesh);

            return std::move(output);
        }

        static void read_mesh(
            const basic_json<>& j,
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

            // FaceIds
            if (!j.contains("face_ids")) {
                const auto& ids = j.at("face_ids");

                mesh.faceID.resize(ids.size());
                for (std::size_t i = 0; i < ids.size(); ++i) {
                    mesh.faceID[i] = ids[i].get<uint32_t>();
                }
            }

        }

        static void write_mesh(
            basic_json<>& j,
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
