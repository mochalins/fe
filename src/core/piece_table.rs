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
    root_index: usize,
}

impl PieceTable {
    pub fn new(content: &str) -> Self {
        let mut buffers = Vec::<Buffer>::with_capacity(2);
        buffers.push(Buffer::new(content));
        buffers.push(Buffer::new(""));

        let num_lines = buffers[0].linebreaks.len();

        let mut pieces = vec![Piece {
            buffer_index: 0,
            start: BufferPosition {
                linebreak_index: 0,
                char_offset: 0,
            },
            end: BufferPosition {
                linebreak_index: 0,
                char_offset: 0,
            },
        }];
        if num_lines > 0 {
            pieces.push(Piece {
                buffer_index: 0,
                start: BufferPosition {
                    linebreak_index: 0,
                    char_offset: 0,
                },
                end: BufferPosition {
                    linebreak_index: num_lines - 1,
                    char_offset: buffers[0].value.chars().count()
                        - 1
                        - buffers[0].linebreaks[num_lines - 1],
                },
            });
        }
        return PieceTable {
            buffers: buffers,
            pieces: pieces,
            free_pieces: Vec::new(),
            nodes: vec![Node {
                piece_index: 0,
                rank: 0,
                left_linebreaks: 0,
                left_chars: 0,
                parent_index: 0,
                left_index: 0,
                right_index: 0,
            }],
            free_nodes: Vec::new(),
            root_index: 0,
        };
    }

    /// Count of linebreaks in piece
    fn piece_linebreak_count(&self, piece: usize) -> usize {
        debug_assert!(piece < self.pieces.len());
        debug_assert!(!self.free_pieces.contains(&piece));

        let piece = &self.pieces[piece];
        if piece.start.linebreak_index > piece.end.linebreak_index {
            return 0;
        }

        let mut linebreaks = piece.end.linebreak_index - piece.start.linebreak_index;
        if piece.start.char_offset == 0 {
            linebreaks += 1;
        }

        return linebreaks;
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
        } else {
            return end_ind - start_ind + 1;
        }
    }

    /// Count of linebreaks in node
    fn node_linebreak_count(&self, node: usize) -> usize {
        debug_assert!(node < self.nodes.len());
        debug_assert!(!self.free_nodes.contains(&node));

        let node = &self.nodes[node];
        return self.piece_linebreak_count(node.piece_index);
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
        let mut line = line;
        while node_ind > 0 {
            let node = &self.nodes[node_ind];

            // Traverse left subtree
            if line < node.left_linebreaks {
                node_ind = node.left_index;
            }
            // Found key match
            else if line < node.left_linebreaks + self.node_linebreak_count(node_ind) {
                break;
            }
            // Traverse right subtree
            else {
                line -= node.left_linebreaks + self.node_linebreak_count(node_ind);
                node_ind = node.right_index;
            }
        }
        return node_ind;
    }

    /// Search for node by char index
    fn search_node_char(&self, node: usize, char_index: usize) -> usize {
        debug_assert!(node < self.nodes.len());
        debug_assert!(!self.free_nodes.contains(&node));

        let mut node_ind: usize = node;
        let mut char_index = char_index;
        while node_ind > 0 {
            let node = &self.nodes[node_ind];

            // Traverse left subtree
            if char_index < node.left_chars {
                node_ind = node.left_index;
            }
            // Found key match
            else if char_index < node.left_chars + self.node_char_count(node_ind) {
                break;
            }
            // Traverse right subtree
            else {
                char_index -= node.left_chars + self.node_char_count(node_ind);
                node_ind = node.right_index;
            }
        }
        return node_ind;
    }
}

#[derive(PartialEq, Debug)]
struct Buffer {
    value: String,
    linebreaks: Vec<usize>,
}

impl Buffer {
    fn new(value: &str) -> Self {
        // "Pseudo-linebreak" at buffer index 0 for simpler line operations
        let mut linebreaks: Vec<usize> = vec![0];
        // '\r' can be safely ignored as lines will be trimmed in use
        for (ind, _) in value.match_indices('\n') {
            linebreaks.push(ind);
        }
        return Buffer {
            value: String::from(value),
            linebreaks: linebreaks,
        };
    }

    fn append(&mut self, value: &str) {
        if value.len() == 0 {
            return;
        }
        let current_len = self.value.chars().count();
        let value = String::from(value);
        // '\r' can be safely ignored as lines will be trimmed in use
        for (ind, _) in value.match_indices('\n') {
            self.linebreaks.push(current_len + ind);
        }
        self.value.push_str(&value);
    }

    /// Convert position to char index in buffer value
    fn position_to_index(&self, position: BufferPosition) -> usize {
        debug_assert!(position.linebreak_index < self.linebreaks.len());
        let result = self.linebreaks[position.linebreak_index] + position.char_offset;
        debug_assert!(result < self.value.chars().count());
        return result;
    }
}

#[derive(Copy, Clone, PartialEq, Debug)]
struct BufferPosition {
    /// Index in buffer's linebreaks vector
    linebreak_index: usize,
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

    /// Count of linebreaks in left subtree
    left_linebreaks: usize,
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
        assert_eq!(b.linebreaks.len(), 4);
        assert_eq!(b.linebreaks[0], 0);
        assert_eq!(b.linebreaks[1], 14);
        assert_eq!(b.linebreaks[2], 25);
        assert_eq!(b.linebreaks[3], 27);

        let b = Buffer::new("");
        assert_eq!(b.value, String::from(""));
        assert_eq!(b.linebreaks.len(), 1);
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
        assert_eq!(b.linebreaks.len(), 5);
        assert_eq!(b.linebreaks[4], 41);

        let append_str_two = " five";
        b.append(append_str_two);
        buf_val.push_str(append_str_two);
        assert_eq!(b.value, buf_val);
        assert_eq!(b.linebreaks.len(), 5);
        assert_eq!(b.linebreaks[4], 41);
    }

    #[test]
    fn piece_table_initialize() {
        let init_str = "sample content\ntest line\r\n3\n";
        let ptable = PieceTable::new(init_str);
        assert_eq!(ptable.nodes.len(), 1);
        assert_eq!(ptable.pieces.len(), 2);
        assert_eq!(ptable.free_nodes.len(), 0);
        assert_eq!(ptable.free_pieces.len(), 0);
        assert_eq!(ptable.buffers.len(), 2);
        assert_eq!(ptable.buffers[0], Buffer::new(init_str));
        assert_eq!(ptable.buffers[1], Buffer::new(""));
        assert_eq!(ptable.root_index, 0)
    }
}
