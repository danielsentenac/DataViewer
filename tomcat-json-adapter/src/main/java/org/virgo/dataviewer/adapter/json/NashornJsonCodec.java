package org.virgo.dataviewer.adapter.json;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import javax.script.ScriptEngine;
import javax.script.ScriptEngineManager;
import javax.script.ScriptException;

public class NashornJsonCodec implements JsonCodec {
    @Override
    public Object read(InputStream inputStream) throws IOException {
        String json = readUtf8(inputStream);
        if (json.trim().isEmpty()) {
            return null;
        }

        ScriptEngine engine = new ScriptEngineManager().getEngineByName("nashorn");
        if (engine == null) {
            throw new IOException("Nashorn JavaScript engine is not available.");
        }

        engine.put("__json_input__", json);
        try {
            return engine.eval("Java.asJSONCompatible(JSON.parse(__json_input__))");
        } catch (ScriptException exception) {
            throw new IOException("Invalid JSON payload.", exception);
        }
    }

    @Override
    public void write(OutputStream outputStream, Object value) throws IOException {
        outputStream.write(stringify(value).getBytes(StandardCharsets.UTF_8));
    }

    private String readUtf8(InputStream inputStream) throws IOException {
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        byte[] chunk = new byte[4096];
        int read;
        while ((read = inputStream.read(chunk)) != -1) {
            buffer.write(chunk, 0, read);
        }
        return new String(buffer.toByteArray(), StandardCharsets.UTF_8);
    }

    @SuppressWarnings("unchecked")
    private String stringify(Object value) throws IOException {
        if (value == null) {
            return "null";
        }
        if (value instanceof String) {
            return quote((String) value);
        }
        if (value instanceof Number || value instanceof Boolean) {
            return String.valueOf(value);
        }
        if (value instanceof Map) {
            StringBuilder builder = new StringBuilder();
            builder.append('{');
            Iterator<Map.Entry<Object, Object>> iterator = ((Map<Object, Object>) value).entrySet().iterator();
            while (iterator.hasNext()) {
                Map.Entry<Object, Object> entry = iterator.next();
                builder.append(quote(String.valueOf(entry.getKey())));
                builder.append(':');
                builder.append(stringify(entry.getValue()));
                if (iterator.hasNext()) {
                    builder.append(',');
                }
            }
            builder.append('}');
            return builder.toString();
        }
        if (value instanceof List) {
            StringBuilder builder = new StringBuilder();
            builder.append('[');
            Iterator<Object> iterator = ((List<Object>) value).iterator();
            while (iterator.hasNext()) {
                builder.append(stringify(iterator.next()));
                if (iterator.hasNext()) {
                    builder.append(',');
                }
            }
            builder.append(']');
            return builder.toString();
        }

        throw new IOException("Unsupported JSON value type: " + value.getClass().getName());
    }

    private String quote(String value) {
        StringBuilder builder = new StringBuilder();
        builder.append('"');
        for (int index = 0; index < value.length(); index++) {
            char current = value.charAt(index);
            switch (current) {
                case '"':
                case '\\':
                    builder.append('\\').append(current);
                    break;
                case '\b':
                    builder.append("\\b");
                    break;
                case '\f':
                    builder.append("\\f");
                    break;
                case '\n':
                    builder.append("\\n");
                    break;
                case '\r':
                    builder.append("\\r");
                    break;
                case '\t':
                    builder.append("\\t");
                    break;
                default:
                    if (current < 0x20) {
                        builder.append(String.format("\\u%04x", (int) current));
                    } else {
                        builder.append(current);
                    }
            }
        }
        builder.append('"');
        return builder.toString();
    }
}
