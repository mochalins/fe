use std::io::{
    stdout,
    Write,
};
use crossterm::{
    event::{
        read,
        Event,
        KeyCode,
    },
    execute,
    terminal::{
        enable_raw_mode,
        disable_raw_mode,    
        EnterAlternateScreen,
        LeaveAlternateScreen,
    },
    Result,
};


fn main() -> Result<()> {
    let mut stdout = stdout();
    enable_raw_mode()?;
    execute!(stdout, EnterAlternateScreen)?;

    loop {
        match read()? {
            Event::Key(event) => {
                match event.code {
                    KeyCode::Char('q') => {
                        break;
                    }
                    _ => {
                        println!("{:?}", event);
                    }
                }
            }
            _ => {
                break;
            }
        }
    } 

    execute!(stdout, LeaveAlternateScreen)?;
    disable_raw_mode()?;

    Ok(())
}
