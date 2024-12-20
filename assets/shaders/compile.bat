glslc.exe %~dp0main.vert -o %~dp0main_vert.spv
glslc.exe %~dp0main.frag -o %~dp0main_frag.spv
glslc.exe %~dp0post.comp -o %~dp0post_comp.spv
glslc.exe %~dp0light.vert -o %~dp0light_vert.spv
glslc.exe %~dp0light.frag -o %~dp0light_frag.spv