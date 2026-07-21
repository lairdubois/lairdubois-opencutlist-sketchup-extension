#include <fstream>
#include <iostream>
#include <unordered_map>
#include <cmath>
#include <algorithm>

#include <nlohmann/json.hpp>
#include <manifold/manifold.h>

using namespace nlohmann;

int main(int argc, char* argv[]) {
    std::ifstream ifs(argc>1?argv[1]:"input.json");
    json j; ifs >> j;

    manifold::MeshGL64 mesh;
    const auto& verts = j["src_meshes"][0]["vertices"];
    mesh.vertProperties.resize(verts.size());
    for (std::size_t i = 0; i < verts.size(); ++i) mesh.vertProperties[i] = verts[i].get<double>();
    mesh.numProp = 3;
    const auto& tris = j["src_meshes"][0]["face_indices"];
    mesh.triVerts.resize(tris.size());
    for (std::size_t i = 0; i < tris.size(); ++i) mesh.triVerts[i] = tris[i].get<uint32_t>();
    const auto& fids = j["src_meshes"][0]["face_ids"];

    // find pinch edge (4,15) occurrences
    struct Occ { std::size_t triangle; uint64_t a,b; };
    std::vector<Occ> occs;
    std::size_t tri_count = mesh.triVerts.size()/3;
    for (std::size_t t=0;t<tri_count;++t){
        uint64_t v[3] = {mesh.triVerts[t*3],mesh.triVerts[t*3+1],mesh.triVerts[t*3+2]};
        for (int e=0;e<3;++e){
            uint64_t a=v[e], b=v[(e+1)%3];
            if ((a==4&&b==15)||(a==15&&b==4)) occs.push_back({t,a,b});
        }
    }
    std::cout << "occurrences: " << occs.size() << std::endl;
    double pa[3] = {mesh.vertProperties[4*3],mesh.vertProperties[4*3+1],mesh.vertProperties[4*3+2]};
    double pb[3] = {mesh.vertProperties[15*3],mesh.vertProperties[15*3+1],mesh.vertProperties[15*3+2]};
    double d[3] = {pb[0]-pa[0],pb[1]-pa[1],pb[2]-pa[2]};
    double dlen = std::sqrt(d[0]*d[0]+d[1]*d[1]+d[2]*d[2]);
    for (auto&c:d) c/=dlen;

    std::vector<double> radial(occs.size()*3);
    std::vector<uint64_t> wid(occs.size());
    for (std::size_t i=0;i<occs.size();++i){
        uint64_t tv[3] = {mesh.triVerts[occs[i].triangle*3],mesh.triVerts[occs[i].triangle*3+1],mesh.triVerts[occs[i].triangle*3+2]};
        uint64_t w=tv[0];
        for (auto cand: tv) if (cand!=4 && cand!=15) { w=cand; break; }
        wid[i]=w;
        double pw[3]={mesh.vertProperties[w*3],mesh.vertProperties[w*3+1],mesh.vertProperties[w*3+2]};
        double rw[3]={pw[0]-pa[0],pw[1]-pa[1],pw[2]-pa[2]};
        double proj=rw[0]*d[0]+rw[1]*d[1]+rw[2]*d[2];
        for(int c=0;c<3;++c) radial[i*3+c]=rw[c]-proj*d[c];
    }
    double e1[3]={radial[0],radial[1],radial[2]};
    double e1len=std::sqrt(e1[0]*e1[0]+e1[1]*e1[1]+e1[2]*e1[2]);
    for(auto&c:e1)c/=e1len;
    double e2[3]={d[1]*e1[2]-d[2]*e1[1], d[2]*e1[0]-d[0]*e1[2], d[0]*e1[1]-d[1]*e1[0]};

    std::vector<std::size_t> order(occs.size());
    std::vector<double> angle(occs.size());
    for (std::size_t i=0;i<occs.size();++i){
        double x=radial[i*3]*e1[0]+radial[i*3+1]*e1[1]+radial[i*3+2]*e1[2];
        double y=radial[i*3]*e2[0]+radial[i*3+1]*e2[1]+radial[i*3+2]*e2[2];
        angle[i]=std::atan2(y,x);
        order[i]=i;
        std::cout << "occ " << i << " tri=" << occs[i].triangle << " face_id=" << fids[occs[i].triangle].get<int>()
                  << " dir=" << occs[i].a << "->" << occs[i].b << " w=" << wid[i]
                  << " angle=" << angle[i]*180.0/M_PI << std::endl;
    }
    std::sort(order.begin(), order.end(), [&](std::size_t x,std::size_t y){return angle[x]<angle[y];});
    std::cout << "sorted order (by angle): ";
    for (auto o: order) std::cout << o << "(face_id=" << fids[occs[o].triangle].get<int>() << ",dir=" << occs[o].a << "->" << occs[o].b << ") ";
    std::cout << std::endl;
    return 0;
}
