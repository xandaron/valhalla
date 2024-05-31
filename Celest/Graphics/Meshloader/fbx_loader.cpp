#include "fbx_loader.h"
#include "OpenFBX/ofbx.h"

Meshloader::FBX_Loader::FBX_Loader(std::string filedir, std::string filename, glm::mat4 preTransform) : Mesh_Loader(filedir, filename, preTransform) {}

bool Meshloader::FBX_Loader::load() {
	FILE* fp;
	fopen_s(&fp, filepath.c_str(), "rb");

	if (!fp) return false;

	fseek(fp, 0, SEEK_END);
	long file_size = ftell(fp);
	fseek(fp, 0, SEEK_SET);
	auto* content = new ofbx::u8[file_size];
	fread(content, 1, file_size, fp);

	ofbx::LoadFlags flags =
		//ofbx::LoadFlags::IGNORE_MODELS |
		ofbx::LoadFlags::IGNORE_BLEND_SHAPES |
		ofbx::LoadFlags::IGNORE_CAMERAS |
		ofbx::LoadFlags::IGNORE_LIGHTS |
		//ofbx::LoadFlags::IGNORE_TEXTURES |
		ofbx::LoadFlags::IGNORE_SKIN |
		ofbx::LoadFlags::IGNORE_BONES |
		ofbx::LoadFlags::IGNORE_PIVOTS |
		//ofbx::LoadFlags::IGNORE_MATERIALS |
		ofbx::LoadFlags::IGNORE_POSES |
		ofbx::LoadFlags::IGNORE_VIDEOS |
		ofbx::LoadFlags::IGNORE_LIMBS |
		//ofbx::LoadFlags::IGNORE_MESHES |
		ofbx::LoadFlags::IGNORE_ANIMATIONS;

	ofbx::IScene* g_scene = ofbx::load((ofbx::u8*)content, file_size, (ofbx::u16)flags);

	if (!g_scene) {
		return false;
	}

	delete[] content;
	fclose(fp);

	const ofbx::Mesh& mesh = *g_scene->getMesh(0);
	const ofbx::GeometryData& geom = mesh.getGeometryData();
	const ofbx::Vec3Attributes positions = geom.getPositions();
	const ofbx::Vec3Attributes normals = geom.getNormals();
	const ofbx::Vec2Attributes uvs = geom.getUVs();

	std::unordered_map<vkMesh::Vertex, uint32_t> vertexLookup{};


	for (int partitionID = 0; partitionID < geom.getPartitionCount(); partitionID++) {
		const ofbx::GeometryPartition& partition = geom.getPartition(partitionID);
		
		for (int polygonID = 0; polygonID < partition.polygon_count; polygonID++) {
			const ofbx::GeometryPartition::Polygon& polygon = partition.polygons[polygonID];
			std::vector<uint32_t> triIndices = triangulate(polygon.vertex_count);

			for (int i = 0; i < triIndices.size(); i++) {
				const ofbx::Vec3 p = positions.get(polygon.from_vertex + triIndices[i]);
				const ofbx::Vec3 n = normals.get(polygon.from_vertex + triIndices[i]);
				const ofbx::Vec2 uv = uvs.get(polygon.from_vertex + triIndices[i]);

				vkMesh::Vertex vert;
				vert.pos = (preTransform * glm::vec4(p.x, p.y, p.z, 0)).xyz;
				vert.color = { 1.0f, 1.0f, 1.0f };
				vert.texCoord = { uv.x, 1.0f - uv.y };
				vert.normal = (preTransform * glm::vec4(n.x, n.y, n.z, 0)).xyz;

				if (!vertexLookup.contains(vert)) {
					vertexLookup[vert] = static_cast<uint32_t>(vertices.size());
					vertices.push_back(vert);
				}

				indices.push_back(vertexLookup[vert]);
			}
		}
	}

	return true;
}