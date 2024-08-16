glslc.exe %~dp0main.vert -o %~dp0main_vert.spv
glslc.exe %~dp0main.frag -o %~dp0main_frag.spv
glslc.exe %~dp0post.comp -o %~dp0post_comp.spv