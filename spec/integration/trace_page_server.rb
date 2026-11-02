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
  # The network mocking e2e page: each button fetches one URL and writes the outcome into its <p>.
  # /api/cors is cross-origin and unresolvable, and the custom header forces a preflight: it only works mocked.
  MOCK_PAGE = <<~HTML
    <!DOCTYPE html>
    <html>
      <head><title>Mock e2e</title></head>
      <body>
        <button id="users">Users</button><p id="users-out"></p>
        <button id="fail">Fail</button><p id="fail-out"></p>
        <button id="echo">Echo</button><p id="echo-out"></p>
        <button id="cors">Cors</button><p id="cors-out"></p>
        <script>
          function show(id, promise, format, failure) {
            promise.then(function (response) { return response.json(); })
              .then(function (body) { document.getElementById(id + '-out').textContent = format(body); })
              .catch(function () { document.getElementById(id + '-out').textContent = failure; });
          }
          document.getElementById('users').addEventListener('click', function () {
            show('users', fetch('/api/users'), function (body) { return body.users.join(','); }, 'users failed');
          });
          document.getElementById('fail').addEventListener('click', function () {
            show('fail', fetch('/api/fail'), function () { return 'fail reached the server'; }, 'request failed');
          });
          document.getElementById('echo').addEventListener('click', function () {
            show('echo', fetch('/api/echo', { headers: { 'x-raider': 'no' } }),
                 function (body) { return 'echo ' + body.raider; }, 'echo failed');
          });
          document.getElementById('cors').addEventListener('click', function () {
            show('cors', fetch('http://mock.raider.test/api/cors', { headers: { 'x-a': '1' } }),
                 function (body) { return 'cors ' + body.ok; }, 'cors failed');
          });
        </script>
      </body>
    </html>
  HTML
  ROUTES = {
    '/mock' => ['200 OK', 'text/html; charset=utf-8', MOCK_PAGE],
    '/api/users' => ['200 OK', 'application/json', '{"users":["real"]}'],
    '/api/fail' => ['200 OK', 'application/json', '{"ok":true}'],
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

  # { lowercase name => value } of the request headers.
  def read_headers(socket)
    headers = {}
    while (line = socket.gets) && line != "\r\n"
      name, value = line.split(':', 2)
      headers[name.downcase] = value.to_s.strip
    end
    headers
  end

  # Answers with the request's x-raider header.
  def echo(headers)
    ['200 OK', 'application/json', %({"raider":"#{headers.fetch('x-raider', 'none')}"})]
  end

  def answer(socket)
    request_line = socket.gets.to_s
    headers = read_headers(socket)
    path = request_line.split[1].to_s.split('?').first
    return redirect(socket, REDIRECTS[path]) if REDIRECTS.key?(path)

    status, type, body = path == '/api/echo' ? echo(headers) : ROUTES.fetch(path, NOT_FOUND)
    sleep(DELAYS.fetch(path, 0))
    socket.write("HTTP/1.1 #{status}\r\nContent-Type: #{type}\r\nContent-Length: #{body.bytesize}\r\n" \
                 "Cache-Control: no-store\r\nConnection: close\r\n\r\n#{body}")
  rescue StandardError => e
    warn "[trace page server] #{e.class}: #{e.message}"
  ensure
    socket.close
  end
end
