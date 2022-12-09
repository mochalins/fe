pub struct View {
    buffer: String,
    rows: u16,
    cols: u16,
    row_offset: u16,
    col_offset: u16,
}

impl View {
    pub fn new(buffer: String, rows: u16) -> Self {
        return View {
            buffer,
            rows,
            cols: 999,
            row_offset: 0,
            col_offset: 0,
        };
    }

    pub fn scroll_down(&mut self, rows: u16) {
        self.row_offset += rows;
    }

    pub fn scroll_up(&mut self, rows: u16) {
        if self.row_offset >= rows {
            self.row_offset -= rows;
        } else {
            self.row_offset = 0;
        }
    }

    pub fn render_lines(&self) -> Vec<String> {
        let mut result: Vec<String> = Vec::new();
        let mut counter: u16 = 0;
        for line in self.buffer.lines() {
            if counter < self.row_offset {
                counter += 1;
                continue;
            } else if counter >= self.rows + self.row_offset {
                break;
            }

            result.push(String::from(line));

            counter += 1;
        }

        return result;
    }
}
