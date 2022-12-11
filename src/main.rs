use clap::Parser;
use crossterm::{
    cursor::{
        position, CursorShape, Hide, MoveDown, MoveLeft, MoveRight, MoveTo, MoveToNextLine, MoveUp,
        RestorePosition, SavePosition, SetCursorShape, Show,
    },
    event::{poll, read, Event, KeyCode},
    execute, queue,
    style::{Print, PrintStyledContent},
    terminal::{
        disable_raw_mode, enable_raw_mode, size, Clear, ClearType, EnterAlternateScreen,
        LeaveAlternateScreen,
    },
    Result,
};
use std::{
    fs::File,
    io::{stdout, Read, Write},
    path::PathBuf,
    time::Duration,
};
mod core;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    files: Vec<PathBuf>,
}

fn main() -> Result<()> {
    let mut buffer: String = String::new();
    let cli = Cli::parse();
    for path in cli.files {
        if path.is_file() {
            let mut file = File::open(path).unwrap();
            file.read_to_string(&mut buffer).unwrap();
        }
    }

    let (cols, rows) = size().unwrap();

    let mut view = core::view::View::new(buffer, rows);

    let mut stdout = stdout();
    enable_raw_mode()?;
    execute!(stdout, EnterAlternateScreen)?;
    execute!(stdout, SetCursorShape(CursorShape::Block))?;

    loop {
        if poll(Duration::from_millis(50))? {
            match read()? {
                Event::Key(event) => match event.code {
                    KeyCode::Char('q') => {
                        break;
                    }
                    KeyCode::Char('j') => {
                        execute!(stdout, MoveLeft(1))?;
                    }
                    KeyCode::Char('l') => {
                        execute!(stdout, MoveRight(1))?;
                    }
                    KeyCode::Char('k') => {
                        if let Ok((_, crow)) = position() {
                            if crow + 1 < rows {
                                execute!(stdout, MoveDown(1))?;
                            } else {
                                view.scroll_down(1);
                            }
                        }
                    }
                    KeyCode::Char('i') => {
                        if let Ok((_, crow)) = position() {
                            if crow > 0 {
                                execute!(stdout, MoveUp(1))?;
                            } else {
                                view.scroll_up(1);
                            }
                        }
                    }
                    _ => {
                        println!("{:?}", event);
                    }
                },
                x => {
                    println!("{:?}", x);
                }
            }
        }
        queue!(stdout, Hide)?;
        queue!(stdout, SavePosition)?;
        queue!(stdout, Clear(ClearType::All))?;
        queue!(stdout, MoveTo(0, 0))?;
        for line in view.render_lines() {
            queue!(stdout, Print(line))?;
            queue!(stdout, MoveToNextLine(1))?;
        }
        queue!(stdout, RestorePosition)?;
        queue!(stdout, Show)?;
        stdout.flush()?;
    }

    execute!(stdout, LeaveAlternateScreen)?;
    disable_raw_mode()?;

    Ok(())
}
