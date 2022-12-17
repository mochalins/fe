#[derive(Debug)]
pub struct PieceTable {
    buffers: Vec<Buffer>,

    /// Arena of pieces, first piece is an empty sentinel piece
    pieces: Vec<Piece>,
    /// Stack of free piece indices
    free_pieces: Vec<usize>,

    /// Arena of nodes, first node is an empty sentinel node
    nodes: Vec<Node>,
    /// Stack of free node indices
    free_nodes: Vec<usize>,

    /// Root node index of piece tree
    piece_tree: usize,
}

impl PieceTable {
    pub fn new(content: &str) -> Self {
        let mut buffers = Vec::<Buffer>::with_capacity(2);
        buffers.push(Buffer::new(content));
        buffers.push(Buffer::new(""));
        return PieceTable {
            buffers: buffers,
            pieces: vec![Piece {
                buffer_index: 0,
                start: BufferPosition {
                    line_index: 0,
                    char_offset: 0,
                },
                end: BufferPosition {
                    line_index: 0,
                    char_offset: 0,
                },
            }],
            free_pieces: Vec::new(),
            nodes: vec![Node {
                piece_index: 0,
                rank: 0,
                left_lines: 0,
                left_chars: 0,
                parent_index: 0,
                left_index: 0,
                right_index: 0,
            }],
            free_nodes: Vec::new(),
            piece_tree: 0,
        };
    }

    /// Count of lines in piece
    fn piece_line_count(&self, piece: usize) -> usize {
        debug_assert!(piece < self.pieces.len());
        debug_assert!(!self.free_pieces.contains(&piece));

        let piece = &self.pieces[piece];
        if piece.start.line_index > piece.end.line_index {
            return 0;
        } else {
            return piece.end.line_index - piece.start.line_index + 1;
        }
    }

    /// Count of chars in piece
    fn piece_char_count(&self, piece: usize) -> usize {
        debug_assert!(piece < self.pieces.len());
        debug_assert!(!self.free_pieces.contains(&piece));

        let piece = &self.pieces[piece];
        let buffer = &self.buffers[piece.buffer_index];
        let start_ind = buffer.position_to_index(piece.start);
        let end_ind = buffer.position_to_index(piece.end);
        if start_ind > end_ind {
            return 0;
        }
        else {
            return end_ind - start_ind + 1;
        }
    }

    /// Count of lines in node
    fn node_line_count(&self, node: usize) -> usize {
        debug_assert!(node < self.nodes.len());
        debug_assert!(!self.free_nodes.contains(&node));

        let node = &self.nodes[node];
        return self.piece_line_count(node.piece_index);
    }

    /// Count of chars in node
    fn node_char_count(&self, node: usize) -> usize {
        debug_assert!(node < self.nodes.len());
        debug_assert!(!self.free_nodes.contains(&node));

        let node = &self.nodes[node];
        return self.piece_char_count(node.piece_index);
    }

    /// Search for node by line index
    fn search_node_line(&self, node: usize, line: usize) -> usize {
        debug_assert!(node < self.nodes.len());
        debug_assert!(!self.free_nodes.contains(&node));

        let mut node_ind: usize = node;
        while node_ind > 0 {
            let node = &self.nodes[node_ind];

            // Traverse left subtree
            if line < node.left_lines {
                node_ind = node.left_index;
            }
            // Found key match
            else if line < node.left_lines + self.node_line_count(node_ind) {
                break;
            }
            // Traverse right subtree
            else {
                node_ind = node.right_index;
            }
        }
        return node_ind;
    }

    /// Search for node by char index
    fn search_node_char(&self, node: usize, char: usize) -> usize {
        debug_assert!(node < self.nodes.len());
        debug_assert!(!self.free_nodes.contains(&node));

        let mut node_ind: usize = node;
        while node_ind > 0 {
            let node = &self.nodes[node_ind];

            // Traverse left subtree
            if char < node.left_chars {
                node_ind = node.left_index;
            }
            // Found key match
            else if char < node.left_chars + self.node_char_count(node_ind) {
                break;
            }
            // Traverse right subtree
            else {
                node_ind = node.right_index;
            }
        }
        return node_ind;
    }
}

#[derive(PartialEq, Debug)]
struct Buffer {
    value: String,
    line_starts: Vec<usize>,
}

impl Buffer {
    fn new(value: &str) -> Self {
        if value.len() == 0 {
            return Buffer {
                value: String::new(),
                line_starts: Vec::new(),
            };
        }
        let value = String::from(value);
        let mut line_starts: Vec<usize> = vec![0];
        for (ind, _) in value.match_indices("\n") {
            if ind < value.chars().count() - 1 {
                line_starts.push(ind + 1);
            }
        }
        return Buffer {
            value: value,
            line_starts: line_starts,
        };
    }

    fn append(&mut self, value: &str) {
        if value.len() == 0 {
            return;
        }
        let current_len = self.value.chars().count();
        if current_len == 0 || self.value.chars().last() == Some('\n') {
            self.line_starts.push(current_len);
        }
        let value = String::from(value);
        for (ind, _) in value.match_indices("\n") {
            if ind < current_len - 1 {
                self.line_starts.push(current_len + ind + 1);
            }
        }
        self.value.push_str(&value);
    }

    /// Convert position to char index in buffer value
    fn position_to_index(&self, position: BufferPosition) -> usize {
        debug_assert!(position.line_index < self.line_starts.len());
        let result = self.line_starts[position.line_index] + position.char_offset;
        debug_assert!(result < self.value.chars().count());
        return result;
    }
}

#[derive(Copy, Clone, PartialEq, Debug)]
struct BufferPosition {
    /// Index in buffer's line_starts vector
    line_index: usize,
    /// Count of chars offset from above referenced line start
    char_offset: usize,
}

#[derive(PartialEq, Debug)]
struct Piece {
    buffer_index: usize,
    /// Start position of piece (inclusive)
    start: BufferPosition,
    /// End position of piece (inclusive)
    end: BufferPosition,
}

#[derive(Debug)]
struct Node {
    piece_index: usize,
    rank: usize,

    /// Count of lines in left subtree
    left_lines: usize,
    /// Count of chars in left subtree
    left_chars: usize,

    parent_index: usize,
    left_index: usize,
    right_index: usize,
}

#[derive(Copy, Clone, Debug)]
struct NodePosition {
    node_index: usize,
    direction: NodeDirection,
}

#[derive(Copy, Clone, Debug)]
enum NodeDirection {
    None,
    Left,
    Right,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn buffer_initialize() {
        let init_str = "sample content\ntest line\r\n3\n";
        let b = Buffer::new(init_str);
        assert_eq!(b.value, String::from(init_str));
        assert_eq!(b.line_starts.len(), 3);
        assert_eq!(b.line_starts[0], 0);
        assert_eq!(b.line_starts[1], 15);
        assert_eq!(b.line_starts[2], 26);

        let b = Buffer::new("");
        assert_eq!(b.value, String::from(""));
        assert_eq!(b.line_starts.len(), 0);
    }

    #[test]
    fn buffer_append() {
        let init_str = "sample content\ntest line\r\n3\n";
        let mut b = Buffer::new(init_str);

        let append_str = "one two three\nfour";
        b.append(append_str);
        let mut buf_val = String::from(init_str);
        buf_val.push_str(append_str);
        assert_eq!(b.value, buf_val);
        assert_eq!(b.line_starts.len(), 5);
        assert_eq!(b.line_starts[3], 28);
        assert_eq!(b.line_starts[4], 42);

        let append_str_two = " five";
        b.append(append_str_two);
        buf_val.push_str(append_str_two);
        assert_eq!(b.value, buf_val);
        assert_eq!(b.line_starts.len(), 5);
        assert_eq!(b.line_starts[4], 42);
    }

    #[test]
    fn piece_table_initialize() {
        let init_str = "sample content\ntest line\r\n3\n";
        let ptable = PieceTable::new(init_str);
        assert_eq!(ptable.nodes.len(), 1);
        assert_eq!(ptable.pieces.len(), 1);
        assert_eq!(ptable.free_nodes.len(), 0);
        assert_eq!(ptable.free_pieces.len(), 0);
        assert_eq!(ptable.buffers.len(), 2);
        assert_eq!(ptable.buffers[0], Buffer::new(init_str));
        assert_eq!(ptable.buffers[1], Buffer::new(""));
        assert_eq!(ptable.piece_tree, 0)
    }
}
