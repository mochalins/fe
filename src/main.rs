use std::{
    fs::{
        File
    },
    io::{
        stdout,
        Read,
        Write,
    },
    path::{
        PathBuf,
    },
    time::{
        Duration,
    },
};
use clap::{
    Parser,
};
use crossterm::{
    cursor::{
        MoveTo,
        MoveToNextLine,
    },
    event::{
        poll,
        read,
        Event,
        KeyCode,
    },
    execute,
    style::{
        Print,
        PrintStyledContent,
    },
    terminal::{
        enable_raw_mode,
        disable_raw_mode,
        size,
        Clear,
        ClearType,
        EnterAlternateScreen,
        LeaveAlternateScreen,
    },
    queue,
    Result,
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

    let mut view = core::view::View::new(
        buffer,
        rows
    );

    let mut stdout = stdout();
    enable_raw_mode()?;
    execute!(stdout, EnterAlternateScreen)?;

    loop {
        queue!(stdout, Clear(ClearType::All))?;
        queue!(stdout, MoveTo(0, 0))?;
        for line in view.render_lines() {
            queue!(stdout, Print(line));
            queue!(stdout, MoveToNextLine(1));
        }
        if poll(Duration::from_millis(100))? {
            match read()? {
                Event::Key(event) => {
                    match event.code {
                        KeyCode::Char('q') => {
                            break;
                        }
                        KeyCode::Char('k') => {
                            view.scroll_down(1);
                        }
                        KeyCode::Char('i') => {
                            view.scroll_up(1);
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
        stdout.flush()?;
    }

    execute!(stdout, LeaveAlternateScreen)?;
    disable_raw_mode()?;

    Ok(())
}
