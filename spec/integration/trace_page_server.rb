# frozen_string_literal: true

require 'socket'

# Serves the trace e2e page over HTTP on 127.0.0.1 (never file://), so the browser makes
# real requests that WebDriver BiDi reports: the page (behind a redirect at /start), its same-origin
# stylesheet and /api.
class TracePageServer
  CSS_RULE = '#title { color: rgb(1, 2, 3); }'
  PAGE = <<~HTML
    <!DOCTYPE html>
    <html>
      <head>
        <title>Trace e2e</title>
        <link rel="stylesheet" href="/style.css">
      </head>
      <body>
        <h1 id="title">Trace</h1>
        <input type="password" id="pw" placeholder="Password">
        <input type="text" id="pw2" autocomplete="current-password" placeholder="Confirm password">
        <input id="name" placeholder="Name">
        <button id="go">Go</button>
        <p id="status"></p>
        <script>
          document.getElementById('go').addEventListener('click', function () {
            fetch('/api').then(function (response) { return response.json(); })
              .then(function (body) { document.getElementById('status').textContent = body.status; });
            console.error('trace e2e error');
          });
        </script>
      </body>
    </html>
  HTML
  ROUTES = {
    '/' => ['200 OK', 'text/html; charset=utf-8', PAGE],
    '/style.css' => ['200 OK', 'text/css', "#{CSS_RULE}\n"],
    '/api' => ['200 OK', 'application/json', '{"status":"answered by /api"}']
  }.freeze
  # A first page that redirects, as a login does; BiDi gives both hops the same request id.
  REDIRECTS = { '/start' => '/' }.freeze
  NOT_FOUND = ['404 Not Found', 'text/plain', 'not found'].freeze
  # /api answers this late, so a network entry's duration_ms has something to measure.
  API_DELAY = 0.3
  # The page answers this late too, so the navigation's duration_ms is measurable.
  PAGE_DELAY = 0.1

  DELAYS = { '/' => PAGE_DELAY, '/api' => API_DELAY }.freeze

  attr_reader :url

  def initialize
    @server = TCPServer.new('127.0.0.1', 0)
    @url = "http://127.0.0.1:#{@server.addr[1]}/"
    @thread = Thread.new { accept_loop }
  end

  def stop
    @thread.kill
    @server.close
  end

  private

  # A thread per connection: Chrome opens speculative connections that may send nothing.
  def accept_loop
    loop do
      client = @server.accept
      Thread.new(client) { |socket| answer(socket) }
    end
  rescue IOError
    nil
  end

  def redirect(socket, location)
    socket.write("HTTP/1.1 302 Found\r\nLocation: #{location}\r\nContent-Length: 0\r\n" \
                 "Cache-Control: no-store\r\nConnection: close\r\n\r\n")
  end

  def answer(socket)
    request_line = socket.gets.to_s
    nil while (line = socket.gets) && line != "\r\n"
    path = request_line.split[1].to_s.split('?').first
    return redirect(socket, REDIRECTS[path]) if REDIRECTS.key?(path)

    status, type, body = ROUTES.fetch(path, NOT_FOUND)
    sleep(DELAYS.fetch(path, 0))
    socket.write("HTTP/1.1 #{status}\r\nContent-Type: #{type}\r\nContent-Length: #{body.bytesize}\r\n" \
                 "Cache-Control: no-store\r\nConnection: close\r\n\r\n#{body}")
  rescue StandardError => e
    warn "[trace page server] #{e.class}: #{e.message}"
  ensure
    socket.close
  end
end
