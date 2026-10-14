import QtQuick 2.4
import "Plex.js" as Plex

Item {
    id: request
    property bool busy: false
    property var xhr: null
    property int generation: 0
    property var failure: null
    function cancel() {
        generation++; deadline.stop();
        var old = xhr; xhr = null; busy = false; failure = null;
        if (old) old.abort();
    }
    function send(method, url, headers, done, failed, milliseconds, format) {
        cancel(); busy = true; failure = failed;
        var version = generation;
        var current = new XMLHttpRequest(); xhr = current;
        current.onreadystatechange = function() {
            if (version !== generation || current.readyState !== XMLHttpRequest.DONE) return;
            deadline.stop(); busy = false; xhr = null; failure = null;
            if (current.status < 200 || current.status >= 300) { failed(current.status); return; }
            var body = {};
            try { if(format === "xml") body=Plex.xmlNode(current.responseXML.documentElement);else if (current.responseText) body = JSON.parse(current.responseText); }
            catch (e) { failed(-2); return; }
            done(body);
        };
        current.open(method, url);
        for (var name in headers) current.setRequestHeader(name, headers[name]);
        deadline.interval = milliseconds || 12000; deadline.start(); current.send();
    }
    Timer {
        id: deadline
        onTriggered: { var callback = request.failure; request.cancel(); if (callback) callback(-1); }
    }
    Component.onDestruction: cancel()
}
