import com.sun.net.httpserver.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;

public class GobangServer {

    static class Room {
        int playerCount = 0;
        List<Move> moves = new CopyOnWriteArrayList<>();
        boolean started = false;
    }

    static class Move {
        int player, row, col;
        Move(int p, int r, int c) { player=p; row=r; col=c; }
    }

    static Map<String, Room> rooms = new ConcurrentHashMap<>();
    static Random rand = new Random();

    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
        server.createContext("/create", new CreateHandler());
        server.createContext("/join", new JoinHandler());
        server.createContext("/move", new MoveHandler());
        server.createContext("/poll", new PollHandler());
        server.setExecutor(Executors.newCachedThreadPool());
        server.start();
        System.out.println("五子棋服务器已启动，端口: 8080");
        System.out.println("请确保手机和此电脑在同一WiFi下");
        System.out.println("手机连接时请使用电脑IP，如: http://192.168.1.5:8080");
    }

    static String readBody(HttpExchange ex) throws IOException {
        InputStream is = ex.getRequestBody();
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        byte[] buf = new byte[1024];
        int n;
        while ((n = is.read(buf)) != -1) baos.write(buf, 0, n);
        return baos.toString(StandardCharsets.UTF_8.name());
    }

    static void sendJson(HttpExchange ex, int code, String json) throws IOException {
        byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().set("Content-Type", "application/json; charset=UTF-8");
        ex.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
        ex.sendResponseHeaders(code, bytes.length);
        try (OutputStream os = ex.getResponseBody()) {
            os.write(bytes);
        }
        ex.close();
    }

    static String json(String... pairs) {
        StringBuilder sb = new StringBuilder("{");
        for (int i = 0; i < pairs.length; i += 2) {
            if (i > 0) sb.append(",");
            sb.append("\"").append(pairs[i]).append("\":");
            String v = pairs[i+1];
            if (v.equals("true") || v.equals("false") || v.startsWith("[") || v.startsWith("{")) {
                sb.append(v);
            } else {
                sb.append("\"").append(v).append("\"");
            }
        }
        sb.append("}");
        return sb.toString();
    }

    static String getField(String json, String key) {
        String p = "\"" + key + "\"\\s*:\\s*\"?([^\",\\}]*)\"?";
        java.util.regex.Matcher m = java.util.regex.Pattern.compile(p).matcher(json);
        return m.find() ? m.group(1).trim() : "";
    }

    static String getQuery(String q, String key) {
        if (q == null) return "";
        String p = key + "=([^&]*)";
        java.util.regex.Matcher m = java.util.regex.Pattern.compile(p).matcher(q);
        return m.find() ? m.group(1).trim() : "";
    }

    static class CreateHandler implements HttpHandler {
        public void handle(HttpExchange ex) throws IOException {
            if ("OPTIONS".equals(ex.getRequestMethod())) {
                sendJson(ex, 200, json("success", "true"));
                return;
            }
            String roomId = String.format("%04d", rand.nextInt(10000));
            Room r = new Room();
            r.playerCount = 1;
            rooms.put(roomId, r);
            sendJson(ex, 200, json("roomId", roomId, "player", "1", "success", "true"));
        }
    }

    static class JoinHandler implements HttpHandler {
        public void handle(HttpExchange ex) throws IOException {
            if ("OPTIONS".equals(ex.getRequestMethod())) {
                sendJson(ex, 200, json("success", "true"));
                return;
            }
            String body = readBody(ex);
            String roomId = getField(body, "roomId");
            Room r = rooms.get(roomId);
            if (r == null || r.playerCount >= 2) {
                sendJson(ex, 200, json("success", "false", "msg", "房间不存在或已满"));
                return;
            }
            r.playerCount = 2;
            r.started = true;
            sendJson(ex, 200, json("success", "true", "player", "2"));
        }
    }

    static class MoveHandler implements HttpHandler {
        public void handle(HttpExchange ex) throws IOException {
            if ("OPTIONS".equals(ex.getRequestMethod())) {
                sendJson(ex, 200, json("success", "true"));
                return;
            }
            try {
                String body = readBody(ex);
                String roomId = getField(body, "roomId");
                int player = Integer.parseInt(getField(body, "player"));
                int row = Integer.parseInt(getField(body, "row"));
                int col = Integer.parseInt(getField(body, "col"));
                Room r = rooms.get(roomId);
                if (r != null) {
                    r.moves.add(new Move(player, row, col));
                }
                sendJson(ex, 200, json("success", "true"));
            } catch (Exception e) {
                sendJson(ex, 200, json("success", "false", "msg", "参数错误"));
            }
        }
    }

    static class PollHandler implements HttpHandler {
        public void handle(HttpExchange ex) throws IOException {
            try {
                String q = ex.getRequestURI().getQuery();
                String roomId = getQuery(q, "roomId");
                String playerStr = getQuery(q, "player");
                String lastStr = getQuery(q, "lastIndex");

                int player = playerStr.isEmpty() ? 0 : Integer.parseInt(playerStr);
                int last = lastStr.isEmpty() ? 0 : Integer.parseInt(lastStr);

                Room r = rooms.get(roomId);
                StringBuilder arr = new StringBuilder("[");
                if (r != null) {
                    for (int i = last; i < r.moves.size(); i++) {
                        if (i > last) arr.append(",");
                        Move m = r.moves.get(i);
                        arr.append("{\"player\":").append(m.player)
                           .append(",\"row\":").append(m.row)
                           .append(",\"col\":").append(m.col).append("}");
                    }
                }
                arr.append("]");
                boolean started = r != null && r.started;
                sendJson(ex, 200, json("moves", arr.toString(), "started", started ? "true" : "false"));
            } catch (Exception e) {
                sendJson(ex, 200, json("moves", "[]", "started", "false"));
            }
        }
    }
}