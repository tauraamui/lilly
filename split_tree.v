// Copyright 2026 The Lilly Edtior contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module boba

pub type SplitNode = EditorLeaf | SplitContainer

pub struct EditorLeaf {
pub mut:
	editor_id int
	doc_id    int
	file_path string
	user_data voidptr
}

pub struct SplitContainer {
pub:
	direction SplitDirection
pub mut:
	children []SplitNode
	ratios   []f64
}

pub enum SplitDirection {
	vertical
	horizontal
}

pub struct SplitTree {
pub mut:
	root             ?SplitNode
	active_editor_id int
}

pub struct EditorInfo {
pub:
	id        int
	doc_id    int
	file_path string
}

pub fn SplitTree.new() SplitTree {
	return SplitTree{
		root:             none
		active_editor_id: 0
	}
}

pub fn (mut t SplitTree) init_with_editor(id int, file_path string, doc_id int) {
	t.root = EditorLeaf{
		editor_id: id
		doc_id:    doc_id
		file_path: file_path
	}
	t.active_editor_id = id
}

pub fn (t SplitTree) is_empty() bool {
	return t.root == none
}

pub fn (t SplitTree) get_active_editor() ?EditorInfo {
	if root := t.root {
		return t.find_editor_by_id(root, t.active_editor_id)
	}
	return none
}

pub fn (t SplitTree) find_editor_by_id(node SplitNode, target_id int) ?EditorInfo {
	match node {
		EditorLeaf {
			if node.editor_id == target_id {
				return EditorInfo{
					id:        node.editor_id
					doc_id:    node.doc_id
					file_path: node.file_path
				}
			}
		}
		SplitContainer {
			for child in node.children {
				if info := t.find_editor_by_id(child, target_id) {
					return info
				}
			}
		}
	}
	return none
}

// Replace the active editor with a new one (for opening files)
pub fn (mut t SplitTree) replace_active_editor(new_id int, new_file_path string) {
	if root := t.root {
		t.root = t.replace_editor_in_node(root, t.active_editor_id, new_id, new_file_path)
		t.active_editor_id = new_id
	}
}

fn (t SplitTree) replace_editor_in_node(node SplitNode, target_id int, new_id int, new_file_path string) SplitNode {
	match node {
		EditorLeaf {
			if node.editor_id == target_id {
				return EditorLeaf{
					editor_id: new_id
					file_path: new_file_path
				}
			}
			return node
		}
		SplitContainer {
			mut new_children := []SplitNode{}
			for child in node.children {
				new_children << t.replace_editor_in_node(child, target_id, new_id, new_file_path)
			}
			return SplitContainer{
				...node
				children: new_children
			}
		}
	}
}

// Insert a vertical split at the active editor
pub fn (mut t SplitTree) insert_vertical_split(new_id int, new_file_path string) bool {
	if root := t.root {
		t.root = t.insert_split_at(root, t.active_editor_id, new_id, new_file_path, .vertical)
		t.active_editor_id = new_id
		return true
	}
	return false
}

// Insert a horizontal split at the active editor
pub fn (mut t SplitTree) insert_horizontal_split(new_id int, new_file_path string) bool {
	if root := t.root {
		t.root = t.insert_split_at(root, t.active_editor_id, new_id, new_file_path, .horizontal)
		t.active_editor_id = new_id
		return true
	}
	return false
}

fn (t SplitTree) insert_split_at(node SplitNode, target_id int, new_id int, new_file_path string, direction SplitDirection) SplitNode {
	new_leaf := EditorLeaf{
		editor_id: new_id
		file_path: new_file_path
	}

	match node {
		EditorLeaf {
			if node.editor_id == target_id {
				// Found target - wrap both in container
				return SplitContainer{
					direction: direction
					children:  [SplitNode(node), SplitNode(new_leaf)]
					ratios:    [0.5, 0.5]
				}
			}
			return node
		}
		SplitContainer {
			// Check if target is a direct child
			for i, child in node.children {
				if child is EditorLeaf {
					if child.editor_id == target_id {
						// Found in this container
						if node.direction == direction {
							// Same direction - just insert
							mut new_children := node.children.clone()
							new_children.insert(i + 1, new_leaf)
							mut new_ratios := []f64{}
							ratio := 1.0 / f64(new_children.len)
							for _ in new_children {
								new_ratios << ratio
							}
							return SplitContainer{
								...node
								children: new_children
								ratios:   new_ratios
							}
						} else {
							// Different direction - wrap target and new in container
							new_container := SplitContainer{
								direction: direction
								children:  [child, new_leaf]
								ratios:    [0.5, 0.5]
							}
							mut new_children := node.children.clone()
							new_children[i] = new_container
							return SplitContainer{
								...node
								children: new_children
							}
						}
					}
				}
			}

			// Not a direct child - recurse
			mut new_children := []SplitNode{}
			for child in node.children {
				new_children << t.insert_split_at(child, target_id, new_id, new_file_path,
					direction)
			}
			return SplitContainer{
				...node
				children: new_children
			}
		}
	}
}

// Get all editor IDs in the tree (in traversal order)
pub fn (t SplitTree) get_all_editor_ids() []int {
	if root := t.root {
		return t.collect_editor_ids(root)
	}
	return []int{}
}

fn (t SplitTree) collect_editor_ids(node SplitNode) []int {
	mut ids := []int{}
	match node {
		EditorLeaf {
			ids << node.editor_id
		}
		SplitContainer {
			for child in node.children {
				ids << t.collect_editor_ids(child)
			}
		}
	}
	return ids
}

// Navigate to next editor
pub fn (mut t SplitTree) navigate_next(do_not_wrap_around bool) bool {
	all_ids := t.get_all_editor_ids()
	if all_ids.len <= 1 {
		return false
	}

	current_idx := all_ids.index(t.active_editor_id)
	if current_idx == -1 {
		t.active_editor_id = all_ids[0]
		return true
	}

	if do_not_wrap_around && current_idx == all_ids.len - 1 {
		return false
	}

	next_idx := if do_not_wrap_around { current_idx + 1 } else { (current_idx + 1) % all_ids.len }
	t.active_editor_id = all_ids[next_idx]
	return true
}

// Navigate to previous editor
pub fn (mut t SplitTree) navigate_prev(do_not_wrap_around bool) bool {
	all_ids := t.get_all_editor_ids()
	if all_ids.len <= 1 {
		return false
	}

	current_idx := all_ids.index(t.active_editor_id)
	if current_idx == -1 {
		t.active_editor_id = all_ids[0]
		return true
	}

	if current_idx == 0 {
		return false
	}

	prev_idx := if do_not_wrap_around {
		current_idx - 1
	} else {
		(current_idx - 1 + all_ids.len) % all_ids.len
	}
	t.active_editor_id = all_ids[prev_idx]
	return true
}

// Get layout information for rendering
pub struct LayoutRect {
pub:
	editor_id int
	x         int
	y         int
	width     int
	height    int
}

pub fn (t SplitTree) get_leftmost_id() int {
	if root := t.root {
		return t.find_leftmost_id(root)
	}
	return -1
}

fn (t SplitTree) find_leftmost_id(node SplitNode) int {
	match node {
		EditorLeaf {
			return node.editor_id
		}
		SplitContainer {
			// the leftmost editor is always in the first child
			return t.find_leftmost_id(node.children[0])
		}
	}
}

pub fn (t SplitTree) get_layout(total_width int, total_height int) []LayoutRect {
	mut rects := []LayoutRect{}
	if root := t.root {
		t.calculate_layout(root, 0, 0, total_width, total_height, mut rects)
	}
	return rects
}

fn (t SplitTree) calculate_layout(node SplitNode, x int, y int, width int, height int, mut rects []LayoutRect) {
	match node {
		EditorLeaf {
			rects << LayoutRect{
				editor_id: node.editor_id
				x:         x
				y:         y
				width:     width
				height:    height
			}
		}
		SplitContainer {
			match node.direction {
				.vertical {
					mut current_x := x
					mut remaining_width := width

					for i, child in node.children {
						child_width := if i == node.children.len - 1 {
							remaining_width
						} else {
							int(f64(width) * node.ratios[i])
						}

						t.calculate_layout(child, current_x, y, child_width, height, mut
							rects)
						current_x += child_width
						remaining_width -= child_width
					}
				}
				.horizontal {
					// split vertically down the height
					mut current_y := y
					mut remaining_height := height

					for i, child in node.children {
						child_height := if i == node.children.len - 1 {
							// last child gets all remaining space
							remaining_height
						} else {
							int(f64(height) * node.ratios[i])
						}

						t.calculate_layout(child, x, current_y, width, child_height, mut
							rects)
						current_y += child_height
						remaining_height -= child_height
					}
				}
			}
		}
		/*
		SplitContainer {
			if node.direction == .vertical {
				// split horizontally across the width
				mut current_x := x
				for i, child in node.children {
					child_width := int(f64(width) * node.ratios[i])
					t.calculate_layout(child, current_x, y, child_width, height, mut rects)
					current_x += child_width
				}
			} else {
				// split vertically down the height
				mut current_y := y
				for i, child in node.children {
					child_height := int(f64(height) * node.ratios[i])
					t.calculate_layout(child, x, current_y, width, child_height, mut rects)
					current_y += child_height
				}
			}
		}
		*/
	}
}

// close the active editor split
pub fn (mut t SplitTree) close_active_split() bool {
	old_active_id := t.active_editor_id

	if root := t.root {
		// navigate to next before closing
		t.navigate_next(false)

		// if we're still on the same ID after navigation, try previous
		if t.active_editor_id == old_active_id {
			t.navigate_prev(false)
		}

		t.root = t.remove_editor_from_node(root, old_active_id)
		return true
	}
	return false
}

fn (t SplitTree) remove_editor_from_node(node SplitNode, target_id int) ?SplitNode {
	match node {
		EditorLeaf {
			if node.editor_id == target_id {
				return none
			}
			return node
		}
		SplitContainer {
			mut new_children := []SplitNode{}
			for child in node.children {
				if remaining := t.remove_editor_from_node(child, target_id) {
					new_children << remaining
				}
			}

			if new_children.len == 0 {
				return none // container is empty
			} else if new_children.len == 1 {
				return new_children[0] // collapse container with single child
			} else {
				// recalculate ratios
				mut new_ratios := []f64{}
				ratio := 1.0 / f64(new_children.len)
				for _ in new_children {
					new_ratios << ratio
				}
				return SplitContainer{
					...node
					children: new_children
					ratios:   new_ratios
				}
			}
		}
	}
}

pub fn (t SplitTree) count() int {
	return t.get_all_editor_ids().len
}
