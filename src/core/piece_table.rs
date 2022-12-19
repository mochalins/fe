mod arena;
mod buffer;
use arena::Arena;
use buffer::{Buffer, BufferPosition};

#[derive(Debug)]
pub struct PieceTable {
    /// Piece tree root node index
    root_index: usize,

    original_buffer: Buffer,
    append_buffer: Buffer,

    /// Arena of pieces, first piece is an empty sentinel piece
    pieces: Arena<Piece>,

    /// Arena of nodes, first node is an empty sentinel node
    nodes: Arena<Node>,
}

/// Piece table functions
impl PieceTable {
    pub fn new(content: &str) -> Self {
        let mut result = PieceTable {
            root_index: 0,
            original_buffer: Buffer::new(content),
            append_buffer: Buffer::new(""),
            pieces: Arena::new(),
            nodes: Arena::new(),
        };

        result.pieces.alloc(Piece {
            start: BufferPosition::new(0, 0),
            end: BufferPosition::new(0, 0),
            append: false,
        });
        if content.len() > 0 {
            result.pieces.alloc(Piece {
                start: result.original_buffer.position_first(),
                end: result.original_buffer.position_last(),
                append: false,
            });
        }

        result.nodes.alloc(Node {
            piece_index: 0,
            rank: 0,
            left_linebreaks: 0,
            left_chars: 0,
            parent_index: 0,
            left_index: 0,
            right_index: 0,
        });

        return result;
    }

    fn get_piece_buffer(&self, piece: &Piece) -> &Buffer {
        return if piece.append {
            &self.append_buffer
        } else {
            &self.original_buffer
        };
    }

    fn get_piece_buffer_mut(&mut self, piece: &Piece) -> &mut Buffer {
        return if piece.append {
            &mut self.append_buffer
        } else {
            &mut self.original_buffer
        };
    }
}

/// Piece functions
impl PieceTable {
    /// Count of linebreaks in piece
    fn piece_linebreaks_count(&self, piece: usize) -> usize {
        let piece = self.pieces.get(piece);
        let buffer = self.get_piece_buffer(piece);
        return buffer.position_range_lines_count(piece.start, piece.end);
    }

    /// Count of chars in piece
    fn piece_char_count(&self, piece: usize) -> usize {
        let piece = self.pieces.get(piece);
        let buffer = self.get_piece_buffer(piece);
        return buffer.position_range_chars_count(piece.start, piece.end);
    }
}

/// Node functions
impl PieceTable {
    /// Count of linebreaks in node
    fn node_linebreaks_count(&self, node: usize) -> usize {
        let node = self.nodes.get(node);
        return self.piece_linebreaks_count(node.piece_index);
    }

    /// Count of chars in node
    fn node_char_count(&self, node: usize) -> usize {
        let node = self.nodes.get(node);
        return self.piece_char_count(node.piece_index);
    }
}

/// Piece tree functions
impl PieceTable {
    /// Search for node by line index
    fn search_node_line(&self, node: usize, line: usize) -> usize {
        let mut node_ind: usize = node;
        let mut line = line;
        while node_ind > 0 {
            let node = self.nodes.get(node_ind);

            // Traverse left subtree
            if line < node.left_linebreaks {
                node_ind = node.left_index;
            }
            // Found key match
            else if line < node.left_linebreaks + self.node_linebreaks_count(node_ind) {
                break;
            }
            // Traverse right subtree
            else {
                line -= node.left_linebreaks + self.node_linebreaks_count(node_ind);
                node_ind = node.right_index;
            }
        }
        return node_ind;
    }

    /// Search for node by char index
    fn search_node_char(&self, node: usize, char_index: usize) -> usize {
        let mut node_ind: usize = node;
        let mut char_index = char_index;
        while node_ind > 0 {
            let node = self.nodes.get(node_ind);

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

#[derive(PartialEq, Debug)]
struct Piece {
    /// Start position of piece (inclusive)
    start: BufferPosition,
    /// End position of piece (inclusive)
    end: BufferPosition,
    append: bool,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn piece_table_initialize() {
        let ptable = PieceTable::new("");
        assert_eq!(ptable.nodes.size(), 1);
        assert_eq!(ptable.pieces.size(), 1);
        assert_eq!(ptable.original_buffer, Buffer::new(""));
        assert_eq!(ptable.append_buffer, Buffer::new(""));
        assert_eq!(ptable.root_index, 0);

        let init_str = "sample content\ntest line\r\n3\n";
        let ptable = PieceTable::new(init_str);
        assert_eq!(ptable.nodes.size(), 1);
        assert_eq!(ptable.pieces.size(), 2);
        assert_eq!(ptable.original_buffer, Buffer::new(init_str));
        assert_eq!(ptable.append_buffer, Buffer::new(""));
        assert_eq!(ptable.root_index, 0);
    }
}
