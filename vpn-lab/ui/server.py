#!/usr/bin/env python3

import os
import subprocess
from urllib.parse import parse_qs
from http.server import HTTPServer, BaseHTTPRequestHandler
import datetime

CLIENTS_DIR = "/etc/openvpn/clients"
SERVER_SCRIPT = os.path.expanduser("~/server.sh")
PORT = 8080


class VPNClientManager(BaseHTTPRequestHandler):
    def list_clients(self):
        if os.path.isdir(CLIENTS_DIR):
            clients = []
            for filename in os.listdir(CLIENTS_DIR):
                filepath = os.path.join(CLIENTS_DIR, filename)
                if os.path.isfile(filepath):
                    stat = os.stat(filepath)
                    created = datetime.datetime.fromtimestamp(stat.st_ctime)
                    clients.append({
                        'name': filename,
                        'created': created.strftime('%Y-%m-%d %H:%M'),
                        'size': stat.st_size
                    })
            return sorted(clients, key=lambda x: x['name'])
        return []

    def get_certificate_content(self, client_name):
        """Read and return the certificate file content"""
        filepath = os.path.join(CLIENTS_DIR, client_name)
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            return f"Error reading certificate: {str(e)}"

    def render_certificate_view(self, client_name):
        """Render the certificate viewing page"""
        cert_content = self.get_certificate_content(client_name)

        html = f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>View Certificate - {client_name}</title>
            <style>
                * {{
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }}
                
                body {{
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                    padding: 20px;
                }}
                
                .container {{
                    max-width: 1200px;
                    margin: 0 auto;
                    background: white;
                    border-radius: 20px;
                    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
                    overflow: hidden;
                }}
                
                .header {{
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 30px 40px;
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    flex-wrap: wrap;
                    gap: 20px;
                }}
                
                .header h1 {{
                    font-size: 1.8rem;
                    font-weight: 300;
                    margin: 0;
                }}
                
                .header .client-name {{
                    background: rgba(255, 255, 255, 0.2);
                    padding: 8px 16px;
                    border-radius: 20px;
                    font-weight: 500;
                }}
                
                .content {{
                    padding: 40px;
                }}
                
                .actions {{
                    display: flex;
                    gap: 15px;
                    margin-bottom: 30px;
                    flex-wrap: wrap;
                }}
                
                .btn {{
                    padding: 12px 24px;
                    border: none;
                    border-radius: 8px;
                    font-size: 0.9rem;
                    font-weight: 600;
                    cursor: pointer;
                    transition: all 0.3s ease;
                    text-decoration: none;
                    display: inline-flex;
                    align-items: center;
                    gap: 8px;
                }}
                
                .btn-secondary {{
                    background: #6c757d;
                    color: white;
                }}
                
                .btn-secondary:hover {{
                    background: #5a6268;
                    transform: translateY(-1px);
                }}
                
                .btn-primary {{
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                }}
                
                .btn-primary:hover {{
                    transform: translateY(-1px);
                    box-shadow: 0 5px 15px rgba(102, 126, 234, 0.3);
                }}
                
                .cert-container {{
                    background: #f8f9fa;
                    border-radius: 10px;
                    padding: 0;
                    border: 1px solid #e9ecef;
                    overflow: hidden;
                }}
                
                .cert-header {{
                    background: #e9ecef;
                    padding: 15px 20px;
                    border-bottom: 1px solid #dee2e6;
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    flex-wrap: wrap;
                    gap: 10px;
                }}
                
                .cert-header h3 {{
                    margin: 0;
                    color: #495057;
                    font-size: 1.1rem;
                }}
                
                .cert-info {{
                    font-size: 0.85rem;
                    color: #6c757d;
                }}
                
                .cert-content {{
                    position: relative;
                }}
                
                .cert-text {{
                    font-family: 'Monaco', 'Menlo', 'Consolas', monospace;
                    font-size: 0.85rem;
                    line-height: 1.4;
                    white-space: pre-wrap;
                    word-wrap: break-word;
                    padding: 20px;
                    margin: 0;
                    background: #ffffff;
                    color: #333;
                    max-height: 500px;
                    overflow-y: auto;
                    border: none;
                    resize: none;
                    width: 100%;
                    box-sizing: border-box;
                }}
                
                .copy-btn {{
                    position: absolute;
                    top: 15px;
                    right: 15px;
                    padding: 8px 12px;
                    background: #007bff;
                    color: white;
                    border: none;
                    border-radius: 5px;
                    cursor: pointer;
                    font-size: 0.8rem;
                    transition: background 0.3s ease;
                }}
                
                .copy-btn:hover {{
                    background: #0056b3;
                }}
                
                .copy-btn.copied {{
                    background: #28a745;
                }}
                
                @media (max-width: 768px) {{
                    .container {{
                        margin: 10px;
                        border-radius: 15px;
                    }}
                    
                    .header {{
                        padding: 20px;
                        text-align: center;
                    }}
                    
                    .content {{
                        padding: 20px;
                    }}
                    
                    .actions {{
                        justify-content: center;
                    }}
                    
                    .cert-text {{
                        font-size: 0.8rem;
                        max-height: 400px;
                    }}
                    
                    .copy-btn {{
                        position: static;
                        margin-bottom: 10px;
                        width: 100%;
                    }}
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>📄 Certificate Viewer</h1>
                    <div class="client-name">{client_name}</div>
                </div>
                
                <div class="content">
                    <div class="actions">
                        <a href="/" class="btn btn-secondary">← Back to Manager</a>
                        <button onclick="downloadCertificate()" class="btn btn-primary">⬇️ Download</button>
                    </div>
                    
                    <div class="cert-container">
                        <div class="cert-header">
                            <h3>Certificate Content</h3>
                            <div class="cert-info">
                                Client: {client_name} • Size: {len(cert_content.encode('utf-8'))} bytes
                            </div>
                        </div>
                        <div class="cert-content">
                            <button onclick="copyCertificate()" class="copy-btn" id="copyBtn">📋 Copy</button>
                            <textarea readonly class="cert-text" id="certText">{cert_content}</textarea>
                        </div>
                    </div>
                </div>
            </div>
            
            <script>
                function copyCertificate() {{
                    const certText = document.getElementById('certText');
                    const copyBtn = document.getElementById('copyBtn');
                    
                    certText.select();
                    certText.setSelectionRange(0, 99999); // For mobile devices
                    
                    try {{
                        document.execCommand('copy');
                        copyBtn.textContent = '✅ Copied!';
                        copyBtn.classList.add('copied');
                        
                        setTimeout(() => {{
                            copyBtn.textContent = '📋 Copy';
                            copyBtn.classList.remove('copied');
                        }}, 2000);
                    }} catch (err) {{
                        console.error('Failed to copy: ', err);
                        copyBtn.textContent = '❌ Failed';
                        setTimeout(() => {{
                            copyBtn.textContent = '📋 Copy';
                        }}, 2000);
                    }}
                }}
                
                function downloadCertificate() {{
                    const content = document.getElementById('certText').value;
                    const element = document.createElement('a');
                    const file = new Blob([content], {{type: 'text/plain'}});
                    element.href = URL.createObjectURL(file);
                    element.download = '{client_name}';
                    document.body.appendChild(element);
                    element.click();
                    document.body.removeChild(element);
                }}
            </script>
        </body>
        </html>
        """
        return html

    def render_page(self, message="", message_type="info"):
        clients = self.list_clients()

        # Message styling based on type
        message_class = {
            "success": "alert-success",
            "error": "alert-error",
            "info": "alert-info"
        }.get(message_type, "alert-info")

        html = f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>OpenVPN Client Manager</title>
            <style>
                * {{
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }}
                
                body {{
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                    padding: 20px;
                }}
                
                .container {{
                    max-width: 1000px;
                    margin: 0 auto;
                    background: white;
                    border-radius: 20px;
                    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
                    overflow: hidden;
                }}
                
                .header {{
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 40px;
                    text-align: center;
                }}
                
                .header h1 {{
                    font-size: 2.5rem;
                    font-weight: 300;
                    margin-bottom: 10px;
                }}
                
                .header p {{
                    opacity: 0.9;
                    font-size: 1.1rem;
                }}
                
                .content {{
                    padding: 40px;
                }}
                
                .alert {{
                    padding: 15px 20px;
                    margin-bottom: 30px;
                    border-radius: 10px;
                    font-weight: 500;
                    animation: slideIn 0.3s ease-out;
                }}
                
                .alert-success {{
                    background: #d4edda;
                    border: 1px solid #c3e6cb;
                    color: #155724;
                }}
                
                .alert-error {{
                    background: #f8d7da;
                    border: 1px solid #f5c6cb;
                    color: #721c24;
                }}
                
                .alert-info {{
                    background: #cce7ff;
                    border: 1px solid #b8daff;
                    color: #004085;
                }}
                
                .section {{
                    margin-bottom: 40px;
                }}
                
                .section h2 {{
                    color: #333;
                    margin-bottom: 20px;
                    font-size: 1.5rem;
                    font-weight: 600;
                    display: flex;
                    align-items: center;
                    gap: 10px;
                }}
                
                .form-container {{
                    background: #f8f9fa;
                    padding: 30px;
                    border-radius: 15px;
                    border: 1px solid #e9ecef;
                }}
                
                .form-group {{
                    display: flex;
                    gap: 15px;
                    align-items: stretch;
                }}
                
                input[type="text"] {{
                    flex: 1;
                    padding: 15px 20px;
                    border: 2px solid #e9ecef;
                    border-radius: 10px;
                    font-size: 1rem;
                    transition: all 0.3s ease;
                    background: white;
                }}
                
                input[type="text"]:focus {{
                    outline: none;
                    border-color: #667eea;
                    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
                }}
                
                .btn {{
                    padding: 15px 30px;
                    border: none;
                    border-radius: 10px;
                    font-size: 1rem;
                    font-weight: 600;
                    cursor: pointer;
                    transition: all 0.3s ease;
                    text-decoration: none;
                    display: inline-flex;
                    align-items: center;
                    gap: 8px;
                }}
                
                .btn-primary {{
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                }}
                
                .btn-primary:hover {{
                    transform: translateY(-2px);
                    box-shadow: 0 10px 20px rgba(102, 126, 234, 0.3);
                }}
                
                .btn-secondary {{
                    background: #6c757d;
                    color: white;
                    padding: 8px 16px;
                    font-size: 0.85rem;
                }}
                
                .btn-secondary:hover {{
                    background: #5a6268;
                    transform: translateY(-1px);
                    box-shadow: 0 5px 15px rgba(108, 117, 125, 0.3);
                }}
                
                .btn-danger {{
                    background: #dc3545;
                    color: white;
                    padding: 8px 16px;
                    font-size: 0.85rem;
                }}
                
                .btn-danger:hover {{
                    background: #c82333;
                    transform: translateY(-1px);
                    box-shadow: 0 5px 15px rgba(220, 53, 69, 0.3);
                }}
                
                .table-container {{
                    background: white;
                    border-radius: 15px;
                    overflow: hidden;
                    box-shadow: 0 5px 15px rgba(0, 0, 0, 0.05);
                    border: 1px solid #e9ecef;
                }}
                
                table {{
                    width: 100%;
                    border-collapse: collapse;
                }}
                
                th {{
                    background: #f8f9fa;
                    padding: 20px;
                    text-align: left;
                    font-weight: 600;
                    color: #495057;
                    border-bottom: 2px solid #e9ecef;
                }}
                
                td {{
                    padding: 20px;
                    border-bottom: 1px solid #f8f9fa;
                    vertical-align: middle;
                }}
                
                tr:hover {{
                    background: #f8f9fa;
                }}
                
                .client-name {{
                    font-weight: 600;
                    color: #333;
                }}
                
                .client-meta {{
                    color: #6c757d;
                    font-size: 0.9rem;
                    margin-top: 5px;
                }}
                
                .action-buttons {{
                    display: flex;
                    gap: 8px;
                    flex-wrap: wrap;
                }}
                
                .empty-state {{
                    text-align: center;
                    padding: 60px 20px;
                    color: #6c757d;
                }}
                
                .empty-state svg {{
                    margin-bottom: 20px;
                    opacity: 0.5;
                }}
                
                .stats {{
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                    gap: 20px;
                    margin-bottom: 40px;
                }}
                
                .stat-card {{
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 25px;
                    border-radius: 15px;
                    text-align: center;
                }}
                
                .stat-number {{
                    font-size: 2.5rem;
                    font-weight: 700;
                    margin-bottom: 5px;
                }}
                
                .stat-label {{
                    opacity: 0.9;
                    font-size: 0.9rem;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                }}
                
                @keyframes slideIn {{
                    from {{
                        opacity: 0;
                        transform: translateY(-10px);
                    }}
                    to {{
                        opacity: 1;
                        transform: translateY(0);
                    }}
                }}
                
                @media (max-width: 768px) {{
                    .container {{
                        margin: 10px;
                        border-radius: 15px;
                    }}
                    
                    .header {{
                        padding: 30px 20px;
                    }}
                    
                    .content {{
                        padding: 20px;
                    }}
                    
                    .form-group {{
                        flex-direction: column;
                    }}
                    
                    .stats {{
                        grid-template-columns: 1fr;
                    }}
                    
                    th, td {{
                        padding: 15px 10px;
                    }}
                    
                    .action-buttons {{
                        flex-direction: column;
                    }}
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🔐 OpenVPN Manager</h1>
                    <p>Secure client certificate management</p>
                </div>
                
                <div class="content">
                    {f'<div class="alert {message_class}">{message}</div>' if message else ''}
                    
                    <div class="stats">
                        <div class="stat-card">
                            <div class="stat-number">{len(clients)}</div>
                            <div class="stat-label">Active Clients</div>
                        </div>
                    </div>
                    
                    <div class="section">
                        <h2>➕ Create New Client</h2>
                        <div class="form-container">
                            <form method="POST" action="/create">
                                <div class="form-group">
                                    <input type="text" name="client_name" placeholder="Enter client name (e.g., john-laptop)" required>
                                    <button type="submit" class="btn btn-primary">Create Client</button>
                                </div>
                            </form>
                        </div>
                    </div>

                    <div class="section">
                        <h2>👥 Client Certificates</h2>
                        <div class="table-container">
        """

        if clients:
            html += """
                            <table>
                                <thead>
                                    <tr>
                                        <th>Client Information</th>
                                        <th style="width: 200px;">Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
            """
            for client in clients:
                html += f"""
                    <tr>
                        <td>
                            <div class="client-name">{client['name']}</div>
                            <div class="client-meta">Created: {client['created']} • Size: {client['size']} bytes</div>
                        </td>
                        <td>
                            <div class="action-buttons">
                                <a href="/view?client={client['name']}" class="btn btn-secondary">📄 View</a>
                                <form method="POST" action="/delete" style="display:inline;" 
                                      onsubmit="return confirm('Are you sure you want to delete {client['name']}? This action cannot be undone.')">
                                    <input type="hidden" name="client_name" value="{client['name']}">
                                    <button type="submit" class="btn btn-danger">🗑️ Delete</button>
                                </form>
                            </div>
                        </td>
                    </tr>
                """
            html += """
                                </tbody>
                            </table>
            """
        else:
            html += """
                            <div class="empty-state">
                                <svg width="64" height="64" viewBox="0 0 24 24" fill="currentColor">
                                    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
                                </svg>
                                <h3>No clients created yet</h3>
                                <p>Create your first VPN client certificate using the form above</p>
                            </div>
            """

        html += """
                        </div>
                    </div>
                </div>
            </div>
        </body>
        </html>
        """
        return html

    def do_GET(self):
        if self.path.startswith('/view?client='):
            # Extract client name from query parameter
            client_name = self.path.split('client=')[1]
            # Validate that the client exists
            client_path = os.path.join(CLIENTS_DIR, client_name)
            if os.path.exists(client_path):
                page = self.render_certificate_view(client_name)
                self.send_response(200)
                self.send_header("Content-type", "text/html")
                self.end_headers()
                self.wfile.write(page.encode("utf-8"))
            else:
                # Client doesn't exist, redirect to main page
                self.send_response(302)
                self.send_header("Location", "/")
                self.end_headers()
        else:
            # Main page
            page = self.render_page()
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(page.encode("utf-8"))

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode()
        data = parse_qs(body)
        client_name = data.get("client_name", [""])[0].strip()

        if self.path == "/create":
            if client_name:
                # Validate client name
                if not client_name.replace('-', '').replace('_', '').isalnum():
                    message = "Client name can only contain letters, numbers, hyphens, and underscores."
                    message_type = "error"
                elif len(client_name) < 3:
                    message = "Client name must be at least 3 characters long."
                    message_type = "error"
                else:
                    try:
                        subprocess.run(
                            ["bash", SERVER_SCRIPT, client_name], check=True)
                        message = f"✅ Client '{client_name}' created successfully!"
                        message_type = "success"
                    except subprocess.CalledProcessError as e:
                        message = f"❌ Error creating client '{client_name}': {e}"
                        message_type = "error"
            else:
                message = "❌ Client name cannot be empty."
                message_type = "error"

        elif self.path == "/delete":
            target_file = os.path.join(CLIENTS_DIR, client_name)
            if os.path.exists(target_file):
                try:
                    os.remove(target_file)
                    message = f"✅ Client '{client_name}' deleted successfully!"
                    message_type = "success"
                except Exception as e:
                    message = f"❌ Error deleting client '{client_name}': {e}"
                    message_type = "error"
            else:
                message = f"❌ Client '{client_name}' does not exist."
                message_type = "error"

        else:
            message = "❌ Unknown action."
            message_type = "error"

        # Redirect back to main page with message
        page = self.render_page(message=message, message_type=message_type)
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(page.encode("utf-8"))


def run_server():
    server_address = ('', PORT)
    httpd = HTTPServer(server_address, VPNClientManager)
    print(f"🚀 OpenVPN Client Manager running at http://localhost:{PORT}")
    print(f"📁 Managing clients in: {CLIENTS_DIR}")
    print(f"📜 Using server script: {SERVER_SCRIPT}")
    httpd.serve_forever()


if __name__ == "__main__":
    run_server()
