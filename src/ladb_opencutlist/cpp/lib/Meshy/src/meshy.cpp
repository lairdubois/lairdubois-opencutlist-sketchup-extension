#include "meshy.hpp"
#include "solver_builder.hpp"

using namespace Meshy;

#ifdef __cplusplus
extern "C" {
#endif

static std::string str_output_;

DLL_EXPORTS char* c_operate(
        const char* s_input
) {

    json j_output;

    try {

        std::stringstream is;
        is << s_input;

        SolverBuilder solver_builder;
        Solver& solver = (*solver_builder.build(is));

        j_output = solver.operate();

    } catch (const std::exception& e) {
        j_output["error"] = e.what();
    } catch (...) {
        j_output["error"] = "Unknown Error";
    }

    str_output_ = j_output.dump();

    return const_cast<char*>(str_output_.c_str());
}

DLL_EXPORTS char* c_version() {
    return const_cast<char*>(MESHY_VERSION);
}

#ifdef __cplusplus
}
#endif