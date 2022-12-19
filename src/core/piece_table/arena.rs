#[derive(Debug)]
pub struct Arena<T> {
    /// Arena of items
    items: Vec<T>,

    /// Stack of indices of free items
    free_items: Vec<usize>,
}

impl<T> Arena<T> {
    pub fn new() -> Self {
        return Arena {
            items: Vec::new(),
            free_items: Vec::new(),
        };
    }

    pub fn alloc(&mut self, item: T) -> usize {
        let mut index: usize = self.items.len();
        if let Some(i) = self.free_items.pop() {
            self.items[i] = item;
            index = i;
        } else {
            self.items.push(item);
        }
        return index;
    }

    pub fn size(&self) -> usize {
        return self.items.len() - self.free_items.len();
    }

    pub fn get(&self, index: usize) -> &T {
        debug_assert!(index < self.items.len());
        debug_assert!(!self.free_items.contains(&index));

        return &self.items[index];
    }

    pub fn get_mut(&mut self, index: usize) -> &mut T {
        debug_assert!(index < self.items.len());
        debug_assert!(!self.free_items.contains(&index));

        return &mut self.items[index];
    }
}
