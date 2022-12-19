#[derive(PartialEq, Debug)]
pub struct Buffer {
    value: String,
    linebreaks: Vec<usize>,
}

impl Buffer {
    pub fn new(value: &str) -> Self {
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

    pub fn append(&mut self, value: &str) -> Option<(BufferPosition, BufferPosition)> {
        if value.len() == 0 {
            return None;
        }
        let current_len = self.value.chars().count();

        let mut result_start = BufferPosition::new(
            self.linebreaks.len() - 1,
            self.chars_count() - self.linebreaks.last().unwrap(),
        );

        let value = String::from(value);
        let mut linebreak_start: bool = false;
        // '\r' can be safely ignored as lines will be trimmed in use
        for (ind, _) in value.match_indices('\n') {
            if ind == 0 {
                linebreak_start = true;
            }
            self.linebreaks.push(current_len + ind);
        }
        self.value.push_str(&value);

        if linebreak_start {
            result_start.linebreak_index += 1;
            result_start.char_offset = 0;
        }

        return Some((result_start, self.position_last()));
    }

    pub fn value(&self) -> &String {
        return &self.value;
    }

    pub fn linebreak(&self, index: usize) -> usize {
        debug_assert!(index < self.linebreaks.len());
        return self.linebreaks[index];
    }

    pub fn linebreaks(&self) -> &Vec<usize> {
        return &self.linebreaks;
    }

    pub fn linebreaks_count(&self) -> usize {
        return self.linebreaks.len();
    }

    pub fn chars_count(&self) -> usize {
        return self.value.chars().count();
    }

    pub fn bytes_count(&self) -> usize {
        return self.value.bytes().count();
    }

    pub fn position_first(&self) -> BufferPosition {
        return BufferPosition::new(0, 0);
    }

    pub fn position_last(&self) -> BufferPosition {
        return BufferPosition::new(
            self.linebreaks.len() - 1,
            self.chars_count() - self.linebreaks.last().unwrap() - 1,
        );
    }

    /// Convert position to char index in buffer value
    pub fn position_to_index(&self, position: BufferPosition) -> usize {
        debug_assert!(position.linebreak_index < self.linebreaks.len());
        let result = self.linebreaks[position.linebreak_index] + position.char_offset;
        debug_assert!(result < self.value.chars().count());
        return result;
    }

    pub fn position_range_chars_count(&self, start: BufferPosition, end: BufferPosition) -> usize {
        let start_ind = self.position_to_index(start);
        let end_ind = self.position_to_index(end);
        if start_ind > end_ind {
            return 0;
        } else {
            return end_ind - start_ind + 1;
        }
    }

    pub fn position_range_lines_count(&self, start: BufferPosition, end: BufferPosition) -> usize {
        if start.linebreak_index > end.linebreak_index {
            return 0;
        }

        let mut linebreaks = end.linebreak_index - start.linebreak_index;
        if start.char_offset == 0 {
            linebreaks += 1;
        }

        return linebreaks;
    }
}

#[derive(Copy, Clone, PartialEq, Debug)]
pub struct BufferPosition {
    /// Index in buffer's linebreaks vector
    pub linebreak_index: usize,
    /// Count of chars offset from above referenced line start
    pub char_offset: usize,
}

impl BufferPosition {
    pub fn new(linebreak_index: usize, char_offset: usize) -> Self {
        return BufferPosition {
            linebreak_index,
            char_offset,
        };
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn new() {
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
    fn append() {
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
    fn positions() {
        let init_str = "sample content\ntest line\r\n3\n";
        let mut b = Buffer::new(init_str);
        let position_first = b.position_first();
        let position_last = b.position_last();
        assert_eq!(position_first, BufferPosition::new(0, 0));
        assert_eq!(position_last, BufferPosition::new(3, 0));
        assert_eq!(b.position_to_index(position_first), 0);
        assert_eq!(b.position_to_index(position_last), b.chars_count() - 1);

        let append_str = "one two three\nfour";
        b.append(append_str);
        let position_last = b.position_last();
        assert_eq!(position_last, BufferPosition::new(4, 4));
        assert_eq!(b.position_to_index(position_last), b.chars_count() - 1);
    }

    #[test]
    fn position_ranges() {
        let init_str = "sample content\ntest line\r\n3\n";
        let mut b = Buffer::new(init_str);
        let position_first = b.position_first();
        let position_last = b.position_last();
        assert_eq!(
            b.position_range_chars_count(position_first, position_last),
            b.chars_count()
        );
        assert_eq!(
            b.position_range_lines_count(position_first, position_last),
            b.linebreaks_count(),
        );

        let append_str = "one two three\nfour";
        b.append(append_str);
        let position_last = b.position_last();
        assert_eq!(
            b.position_range_chars_count(position_first, position_last),
            b.chars_count()
        );
        assert_eq!(
            b.position_range_lines_count(position_first, position_last),
            b.linebreaks_count(),
        );
    }
}
