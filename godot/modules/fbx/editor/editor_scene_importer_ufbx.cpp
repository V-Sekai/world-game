/**************************************************************************/
/*  editor_scene_importer_ufbx.cpp                                        */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#include "editor_scene_importer_ufbx.h"

#ifdef TOOLS_ENABLED

#include "modules/fbx/fbx_document.h"

#include "core/config/project_settings.h"
#include "editor/editor_settings.h"

uint32_t EditorSceneFormatImporterUFBX::get_import_flags() const {
	return ImportFlags::IMPORT_SCENE | ImportFlags::IMPORT_ANIMATION;
}

void EditorSceneFormatImporterUFBX::get_extensions(List<String> *r_extensions) const {
	r_extensions->push_back("fbx");
}

Node *EditorSceneFormatImporterUFBX::import_scene(const String &p_path, uint32_t p_flags,
		const HashMap<StringName, Variant> &p_options,
		List<String> *r_missing_deps, Error *r_err) {
	Ref<FBXDocument> fbx;
	fbx.instantiate();
	Ref<FBXState> state;
	state.instantiate();
	print_verbose(vformat("FBX path: %s", p_path));
	String path = ProjectSettings::get_singleton()->globalize_path(p_path);
	bool allow_geometry_helper_nodes = p_options.has("fbx/allow_geometry_helper_nodes") ? (bool)p_options["fbx/allow_geometry_helper_nodes"] : false;
	if (allow_geometry_helper_nodes) {
		state->set_allow_geometry_helper_nodes(allow_geometry_helper_nodes);
	}
	p_flags |= EditorSceneFormatImporter::IMPORT_USE_NAMED_SKIN_BINDS;
	Error err = fbx->append_from_file(path, state, p_flags, p_path.get_base_dir());
	if (err != OK) {
		if (r_err) {
			*r_err = FAILED;
		}
		return nullptr;
	}
#ifndef DISABLE_DEPRECATED
	bool trimming = p_options.has("animation/trimming") ? (bool)p_options["animation/trimming"] : false;
	bool remove_immutable = p_options.has("animation/remove_immutable_tracks") ? (bool)p_options["animation/remove_immutable_tracks"] : true;
	return fbx->generate_scene(state, (float)p_options["animation/fps"], trimming, remove_immutable);
#else
	return fbx->generate_scene(state, (float)p_options["animation/fps"], (bool)p_options["animation/trimming"], (bool)p_options["animation/remove_immutable_tracks"]);
#endif
}

Variant EditorSceneFormatImporterUFBX::get_option_visibility(const String &p_path, bool p_for_animation,
		const String &p_option, const HashMap<StringName, Variant> &p_options) {
	String file_extension = p_path.get_extension().to_lower();
	if (file_extension != "gltf" && p_option.begins_with("gltf/")) {
		return false;
	}
	if (file_extension != "fbx" && p_option.begins_with("fbx/")) {
		return false;
	}
	return true;
}

void EditorSceneFormatImporterUFBX::get_import_options(const String &p_path,
		List<ResourceImporter::ImportOption> *r_options) {
	r_options->push_back(ResourceImporterScene::ImportOption(PropertyInfo(Variant::BOOL, "fbx/allow_geometry_helper_nodes"), false));
	r_options->push_back(ResourceImporterScene::ImportOption(PropertyInfo(Variant::INT, "fbx/embedded_image_handling", PROPERTY_HINT_ENUM, "Discard All Textures,Extract Textures,Embed as Basis Universal,Embed as Uncompressed", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_UPDATE_ALL_IF_MODIFIED), FBXState::HANDLE_BINARY_EXTRACT_TEXTURES));
}

#endif // TOOLS_ENABLED
