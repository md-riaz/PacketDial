use clap::{Parser, Subcommand};
use interprocess::local_socket::LocalSocketStream;
use serde_json::json;
use std::io::{BufRead, BufReader, Write};

#[derive(Parser)]
#[command(name = "pd")]
#[command(about = "PacketDial CLI Controller", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Start a call to a URI
    Dial {
        /// SIP URI or number (e.g. 100, sip:100@domain)
        uri: String,
        /// Account ID to use (optional, defaults to first found)
        #[arg(short, long)]
        account: Option<String>,
    },
    /// Answer a ringing call
    Answer,
    /// Hang up the active call
    Hangup,
    /// Mute or unmute
    Mute {
        #[arg(value_name = "on|off")]
        status: String,
    },
    /// Hold or resume
    Hold {
        #[arg(value_name = "on|off")]
        status: String,
    },
    /// Listen to events in real-time
    Events,
}

fn main() {
    let cli = Cli::parse();
    // Local socket name used for Named Pipe on Windows
    let name = "PacketDial.API";

    let mut stream = match LocalSocketStream::connect(name) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Error: Could not connect to PacketDial engine ({}).", e);
            eprintln!("Is the application running?");
            std::process::exit(1);
        }
    };

    match cli.command {
        Commands::Dial { uri, account } => {
            let payload = if let Some(acc) = account {
                json!({ "account_id": acc, "uri": uri })
            } else {
                // If account is missing, we pick the first one from global ACCOUNTS in DLL
                // But for now, we'll just send uri and let DLL handle account if it can
                json!({ "uri": uri })
            };
            send_command(&mut stream, "CallStart", payload);
        }
        Commands::Answer => {
            send_command(&mut stream, "CallAnswer", json!({}));
        }
        Commands::Hangup => {
            send_command(&mut stream, "CallHangup", json!({}));
        }
        Commands::Mute { status } => {
            let muted = status.to_lowercase() == "on" || status.to_lowercase() == "true";
            send_command(&mut stream, "CallMute", json!({ "muted": muted }));
        }
        Commands::Hold { status } => {
            let hold = status.to_lowercase() == "on" || status.to_lowercase() == "true";
            send_command(&mut stream, "CallHold", json!({ "hold": hold }));
        }
        Commands::Events => {
            listen_events(stream);
        }
    }
}

fn send_command(stream: &mut LocalSocketStream, cmd_type: &str, payload: serde_json::Value) {
    let msg = json!({ "type": cmd_type, "payload": payload }).to_string() + "\n";
    if let Err(e) = stream.write_all(msg.as_bytes()) {
        eprintln!("Error sending command: {}", e);
        return;
    }

    // Read one-line JSON response
    let mut reader = BufReader::new(stream);
    let mut response = String::new();
    if let Ok(_) = reader.read_line(&mut response) {
        if let Ok(v) = serde_json::from_str::<serde_json::Value>(&response) {
            let rc = v["payload"]["rc"].as_i64().unwrap_or(-1);
            if rc == 0 {
                println!("Success (rc=0)");
            } else {
                println!("Failed (rc={})", rc);
            }
        } else {
            println!("Response: {}", response.trim());
        }
    }
}

fn listen_events(stream: LocalSocketStream) {
    println!("Listening for PacketDial events (Ctrl+C to stop)...");
    let reader = BufReader::new(stream);
    for line in reader.lines() {
        if let Ok(l) = line {
            if let Ok(v) = serde_json::from_str::<serde_json::Value>(&l) {
                // Ignore command responses in event stream
                if v["type"] == "CommandResponse" {
                    continue;
                }

                let timestamp = chrono::Local::now().format("%H:%M:%S");
                println!("[{}] {}", timestamp, l);
            }
        }
    }
}
