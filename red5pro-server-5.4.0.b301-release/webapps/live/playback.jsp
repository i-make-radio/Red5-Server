<%@ page language="java" contentType="text/html; charset=utf-8" pageEncoding="UTF-8"%>
<%@ page import="java.net.Inet4Address,java.net.URLConnection"%>
<%@ page import="com.red5pro.server.secondscreen.net.NetworkUtil"%>
<%@ page import="java.io.*,java.util.Map,java.util.ArrayList,java.util.regex.*,java.net.URL,java.nio.charset.Charset"%>
<%
  String cookieStr = "";
  String cookieName = "storedIpAddress";
  Pattern addressPattern = Pattern.compile("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$");

  String host_success = "[Address Resolver]";
  ArrayList<String> host_errors = new ArrayList<String>();
  String ip = null;
  String hostname = request.getServerName();
  String scheme = request.getScheme();
  String localIp = NetworkUtil.getLocalIpAddress();
  boolean ipExists = false;
  boolean isSecure = scheme == "https";
  String kvUrlParams = "";
  String delimiter = ";";
  Map<String, String[]> parameters = request.getParameterMap();
  for(String parameter : parameters.keySet()) {
    if (!parameter.equals("")) {
      kvUrlParams += parameter + "=" + request.getParameter(parameter) + delimiter;
    }
  }

  // Flip localIp to null if unknown.
  // localIp = addressPattern.matcher(localIp).find() ? localIp : null;

  // First check if provided as a query parameter...
  if(request.getParameter("host") != null) {
    ip = request.getParameter("host");
    host_success = "[Address Resolver] Host provided as query parameter.";
    // ip = addressPattern.matcher(ip).find() ? ip : null;
  }

  Cookie cookie;
  Cookie[] cookies = request.getCookies();

  // If we have stored cookies check if already stored ip address by User.
  if(ip == null && cookies != null) {
    for(int i = 0; i < cookies.length; i++) {
      cookie = cookies[i];
      cookieStr += cookie.getName() + "=" + cookie.getValue() + "; ";
      if(cookie.getName().equals(cookieName)) {
        ip = cookie.getValue();
        host_success = "[Address Resolver] Host provided as cookie value.";
        // ip = addressPattern.matcher(ip).find() ? ip : null;
        break;
      }
    }
  }

  // Is a valid IP address from stored IP by User:
  if(ip == null) {

    ip = localIp;

    if(ip == null) {// && addressPattern.matcher(ip).find()) {
      // The IP returned from NetworkUtils is valid...
      host_success = "[Address Resolver] Host provided from NetworkUtils.";
    }
    else {

      // Invoke AWS service
      String errorPattern = "^Unknown.*";
      URL whatismyip = new URL("http://checkip.amazonaws.com");
      URLConnection connection = whatismyip.openConnection();
      connection.setConnectTimeout(5000);
      connection.setReadTimeout(5000);
      BufferedReader in = null;
      try {
        in = new BufferedReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));
        ip = in.readLine();
        ip = "Unknown. Use ifconfig or ipconfig";
        if (ip.matches(errorPattern)) {
          ip = null;
          host_errors.add("[Address Resolver] Could not determine address from AWS service.");
        }
      }
      catch(Exception e) {
        ip = null;
        host_errors.add("[Address Resolver] Exception in request on AWS: " + e.getMessage() + ".");
      }
      finally {
        if (in != null) {
          try {
            in.close();
          }
          catch (IOException e) {
            e.printStackTrace();
          }
        }
      }

      // If failure in AWS service and/or IP still null => flag to show alert.
    }

  }

  if (isSecure) {
    String tmpIP = ip;
    ip = hostname;
    hostname = tmpIP;
    host_success = "[Address Resolver] Host determined from secure address.";
  }
  else if (ip == null) {
    ip = hostname;
    host_success = "[Address Resolver] Host determined from url.";
  }

  ipExists = ip != null && !ip.isEmpty();
  if (!ipExists) {
    host_success = "[Address Resolver] Could not determine host from service and utils.";
  }
%>
<%@ page import="org.springframework.context.ApplicationContext,
          com.red5pro.server.secondscreen.net.NetworkUtil,
          org.springframework.web.context.WebApplicationContext,
          com.infrared5.red5pro.examples.service.LiveStreamListService,
          java.util.Map.Entry,
          java.util.Map,
          java.util.Iterator"%>
<%
  //VOD streams list
  String host = ip;
  String protocol = request.getScheme();
  String ice = null;
  String tech = null;
  String playlistFlag = "0";

  if (request.getParameter("view") != null) {
    tech = request.getParameter("view");
  }
  if (request.getParameter("ice") != null) {
    ice = request.getParameter("ice");
  }
  if (request.getParameter("playlists") != null) {
    playlistFlag = request.getParameter("playlists");
  }

  ApplicationContext appCtx = (ApplicationContext) application.getAttribute(WebApplicationContext.ROOT_WEB_APPLICATION_CONTEXT_ATTRIBUTE);
  String baseUrl = request.getScheme() + "://" + request.getServerName() + ":" + request.getServerPort();
%>
<!doctype html>
<html lang="eng">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Welcome to the Red5 Pro Server Pages!">
    <link rel="stylesheet" href="css/main.css">
    <link href="https://fonts.googleapis.com/css?family=Lato:400,700" rel="stylesheet" type="text/css">
    <title>Video On Demand Playback with the Red5 Pro Server!</title>
    <link href="//vjs.zencdn.net/5.19/video-js.min.css" rel="stylesheet">
    <script src="//unpkg.com/video.js/dist/video.js"></script>
    <script src="//unpkg.com/videojs-contrib-hls/dist/videojs-contrib-hls.js"></script>
    <script src="//unpkg.com/videojs-flash/dist/videojs-flash.js"></script>
    <style>
      object:focus {
        outline:none;
      }

      #live-page-subcontent {
        text-align: center;
        position: relative;
        width: 100%;
        height: 230px;
        overflow: hidden;
      }

      #live-container {
        position: absolute;
      }

      #live-image-container {
        width: 540px;
      }

      #live-page-img {
        width: 100%;
      }

      .stream-menu-listing {
        list-style: none;
        padding: 0;
        margin: 0;
      }

      .no-streams-entry {
        padding-left: 20px;
      }

      .streaming-menu-content {
        margin-top: 30px;
        margin-bottom: 30px;
      }

      .stream-listing {
        padding: 0 20px 20px 20px;
        border-bottom: 1px solid #e3e3e3;
      }

      .stream-header {
        margin: 10px 0;
      }

      .stream-container {
        margin-top: 20px;
        text-align: center;
        background-color: rgb(239, 239, 239);
        border: 1px solid #e3e3e3;
        border-radius: 4px;
      }

      .stream-header {
        margin-top: 8px;
      }

      .container-hidden {
        width: 0px;
        height: 0px;
        visibility: hidden;
        margin-top: 0px;
      }

      .container-padding {
        padding: 10px 0 20px 0;
      }

      .download-link {
        padding-top: 20px;
      }

      #video-container {
        border-radius: 5px;
        background-color: #e3e3e3;
        padding: 10px;
      }

      #status-field {
        text-align: center;
        padding: 10px;
        color: #fff;
        margin: 10px 0;
      }

      .status-alert {
        background-color: rgb(227, 25, 0);
      }

      .status-message {
        background-color: #aaa;
      }

      #event-log-field {
        background-color: #c0c0c0;
        border-radius: 6px;
        padding: 10px;
        margin: 14px;
      }

      #video-holder, #red5pro-subscriber {
        width: 100%;
      }

      .red5pro-media-control-bar {
        min-height: 40px;
      }

      template { display: none }
    </style>
    <script src="//webrtchacks.github.io/adapter/adapter-latest.js"></script>
    <script src="lib/screenfull/screenfull.min.js"></script>
    <link href="lib/red5pro/red5pro-media.css" rel="stylesheet"></script>
    <script>
      // Shim so we can style in IE6/7/8
      document.createElement('template');
    </script>
  </head>
  <body>
    <template id="video-playback">
      <div id="video-container">
            <div id="video-holder">
              <video id="red5pro-subscriber"
                      controls autoplay playsinline
                      class="red5pro-media red5pro-media-background">
              </video>
            </div>
            <div id="status-field" class="status-message"></div>
            <div id="event-log-field" class="event-log-field">
              <div style="padding: 10px 0">
                <p><span style="float: left;">Event Log:</span><button id="clear-log-button" style="float: right;">clear</button></p>
                <div style="clear: both;"></div>
              </div>
            </div>
      </div>
    </template>
    <template id="flash-playback">
      <div id="video-container">
            <div id="video-holder" style="height:405px;">
              <object type="application/x-shockwave-flash" id="red5pro-subscriber" name="red5pro-subscriber" align="middle" data="lib/red5pro/red5pro-subscriber.swf" width="100%" height="100%" class="red5pro-media-background red5pro-media">
                <param name="quality" value="high">
                <param name="wmode" value="opaque">
                <param name="bgcolor" value="#000000">
                <param name="allowscriptaccess" value="always">
                <param name="allowfullscreen" value="true">
                <param name="allownetworking" value="all">
            </object>
          </div>
      </div>
    </template>
    <div class="header-bar clear-fix">
      <div id="header-field" class="clear-fix">
        <p class="left"><a class="red5pro-header-link" href="/">
            <img class="red5pro-logo-header" src="images/red5pro_logo.svg">
        </a></p>
      </div>
      <!-- view jsp_header for details on variables used. -->
      
      <!-- Display IP Address used through the page -->
      <div id="ip-field">
        <% if (ipExists) { %>
          <p><span class="black-text">Your server IP address is:</span>&nbsp;&nbsp;<span id="ip-address-field" class="red-text medium-font-size"><%= ip %></span></p>
        <% } else { %>
          <p><span class="black-text">Uh-Oh!!</span></p>
        <% } %>
        <p><a id="ip-overlay-button" class="white-text" href="#">Why would I need to know the server IP address?</a></p>
        <p><a id="ip-incorrect-button" class="black-text" href="#">Not the correct IP address?</a></p>
      </div>
      
      <!-- Overlay explaining what the IP Address is used for. -->
      <div id="ip-overlay" class="hidden">
        <p class="overlay-close-button"><a id="ip-overlay-close" href="#" class="red-text">Close</a></p>
        <p>This IP address needs to be provided to applications integrated with the Red5 Pro SDKs.</p>
        <p>If using the example projects from our <a id="header-github-link" class="link" href="http://github.com/red5pro" target="_blank">Github</a>, you will enter this IP into the <strong>Server</strong> input field of the Settings menu.</p>
        <hr>
        <p class="top-nudge"><a id="ip-overlay-ip-incorrect-button" href="#" class="red-text">Not the correct IP address?</a></p>
      </div>
      
      <!-- Overlay to allow User to update IP Address to be used. -->
      <div id="ip-address-overlay" class="hidden">
        <p class="overlay-close-button"><a id="ip-overlay-close" href="#" class="red-text">Close</a></p>
        <p class="black-text" style="font-weight: bold">Do you think the server IP address above is incorrect?</p>
        <div>
          <p>Select from the following suggestions:</p>
          <table id="ip-suggestions-table">
            <tbody><tr><td class="red-text">No suggestions.</tr></td>
          </table>
        </div>
        <hr>
        <p class="black-text"> Or enter in the correct address below:</p>
        <p id="ip-input-error-field" class="hidden red-text">Invalid IP address.</p>
        <input id="ip-address-input-field" type="text">
        <button id="ip-address-input-submit">submit</button>
      </div>
      <script>
      (function(window, document) {
        'use strict';
      
        // Host IP state
        var hostErrors = "<%= host_errors %>";
        if (hostErrors && hostErrors.length > 0) {
          var errors = hostErrors.substring(1, hostErrors.length - 1).split(',');
          for (var i = 0; i < errors.length; i++) {
            console.warn(errors[i]);
          }
        }
        console.log("<%= host_success %>");
        var currentIp = "<%= ip %>";
        var hasValidIp = <%= ipExists %>;
        var isSecureProtocol = <%= isSecure %>;
        var hostname = "<%= hostname %>";
        var ipAddressField = document.getElementById('ip-address-field');
        var validIpRegex = /^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$/gi;
      
        // IP Overlay
        var isOverlayShown = false;
        var isIpAddressOverlayShown = false;
      
        // Element References
        var ipOverlay = document.getElementById('ip-overlay');
        var ipAddressOverlay = document.getElementById('ip-address-overlay');
        var ipOverlayButton = document.getElementById('ip-overlay-button');
        var ipIncorrectButton = document.getElementById('ip-incorrect-button');
        var ipOverlayIpIncorrectButton = document.getElementById('ip-overlay-ip-incorrect-button');
        var githubLink = document.getElementById('header-github-link');
        var ipAddressInput = document.getElementById('ip-address-input-field');
        var ipAddressInputSubmit = document.getElementById('ip-address-input-submit');
        var ipAddressErrorField = document.getElementById('ip-input-error-field');
        var ipSuggestionsTable = document.getElementById('ip-suggestions-table');
      
        // Listeners to Change in IP
        var ipChangeListeners = [];
        var registerIpChangeListener = function(func, immediatelyInvoke) {
          if(immediatelyInvoke) {
            func.call(null, currentIp);
          }
          ipChangeListeners.push(func);
        };
        var unregisterIpChangeListener = function(func) {
          var i = ipChangeListeners.length;
          while(--i > -1) {
            if(ipChangeListeners[i] === func) {
              ipChangeListeners.splice(i, 1);
              break;
            }
          }
        };
        var notifyIpChangeListeners = function(newValue) {
          var i = ipChangeListeners.length;
          while(--i > -1) {
            ipChangeListeners[i].call(null, newValue);
          }
        };
        window.r5pro_registerIpChangeListener = registerIpChangeListener;
        window.r5pro_unregisterIpChangeListener = unregisterIpChangeListener;
      
        var normalizeIp = function(value) {
          var isValid = value !== null;
          isValid = isValid && value !== undefined;
          isValid = isValid && value !== "null";
          isValid = isValid && value !== "undefined";
          return isValid ? value : null;
        };
        var fillInIpSuggestions = function(currentIp) {
          var items = [];
          var localIp = normalizeIp("<%= localIp %>");
          var addIpToList = function(value) {
            if(value !== null && currentIp !== value) {
            items.push('<tr>' +
                '<td>' +
                  '<a class="red-text ip-suggestion-link" href="#">' +
                    value +
                  '</a>' +
                '</td>' +
              '</tr>');
            }
          };
          addIpToList(localIp);
          if (localIp !== hostname) {
            addIpToList(hostname);
          }
          if(items.length > 0) {
            ipSuggestionsTable.innerHTML = items.join('');
          }
        }
        var updateAndStoreUserEnteredIpAddress = function(value) {
          var expiry = 60*60*24;
          if(ipAddressField.hasOwnProperty('innerText')) {
            ipAddressField.innerText = value;
          }
          else {
            ipAddressField.textContent = value;
          }
          document.cookie = '<%= cookieName %>=' + value + '; path=/; max-age=' + expiry;
          currentIp = value;
          notifyIpChangeListeners(value);
          // update URL + query params
          var params = '<%= kvUrlParams %>'.split(';');
          var i = params.length;
          while (--i > -1) {
            var kv = params[i].split('=');
            if (kv[0] === 'host') {
              params[i] = 'host=' + value;
            }
            else if (kv[0] === '') {
              params.splice(i, 1);
            }
          }
          var query = params.length > 1 ? params.join('&') : params[0]
          window.location = [(window.location.origin + window.location.pathname), query].join('?');
        };
      
        var toggleOverlay = function(event) {
          event.preventDefault();
          event.stopPropagation();
          if(!isOverlayShown) {
            showOverlay();
          }
          else {
            hideOverlay();
          }
        };
        var showOverlay = function() {
          isOverlayShown = true;
          if(isIpAddressOverlayShown) {
             hideIpAddressOverlay();
          }
          ipOverlay.classList.remove('hidden');
        };
        var hideOverlay = function() {
          isOverlayShown = false;
          ipOverlay.classList.add('hidden');
        };
        var handleOverlayClose = function(event) {
          if(event.target !== githubLink &&
              event.target !== ipOverlayIpIncorrectButton) {
            event.stopPropagation();
            event.preventDefault();
            hideOverlay();
            return false;
          }
          else if(event.target === ipOverlayIpIncorrectButton) {
            toggleIpAddressOverlay(event);
          }
          return true;
        };
      
        var toggleIpAddressOverlay = function(event) {
          event.stopPropagation();
          event.preventDefault();
          if(!isIpAddressOverlayShown) {
            showIpAddressOverlay();
          }
          else {
            hideIpAddressOverlay();
          }
          return false;
        };
        var showIpAddressOverlay = function() {
          isIpAddressOverlayShown = true;
          if(isOverlayShown) {
            hideOverlay();
          }
          ipAddressOverlay.classList.remove('hidden');
        };
        var hideIpAddressOverlay = function() {
          isIpAddressOverlayShown = false;
          ipAddressOverlay.classList.add('hidden');
          ipAddressErrorField.classList.add('hidden');
        };
        var handleIpAddressOverlayClose = function(event) {
          if(event.target !== ipAddressInput &&
              event.target !== ipAddressInputSubmit &&
              !event.target.classList.contains('ip-suggestion-link')) {
              event.preventDefault();
              event.stopPropagation();
              hideIpAddressOverlay();
              return false;
          }
          else if(event.target.classList.contains('ip-suggestion-link')) {
            var value;
            event.preventDefault();
            event.stopPropagation();
            hideIpAddressOverlay();
            if(event.target.hasOwnProperty('innerText')) {
              value = event.target.innerText;
            }
            else {
              value = event.target.textContent;
            }
            updateAndStoreUserEnteredIpAddress(value);
            return false;
          }
          return true;
        };
        var handleIpAddressInputSubmit = function(event) {
          var value = ipAddressInput.value;
          event.stopPropagation();
          event.preventDefault();
          ipAddressErrorField.classList.add('hidden');
          // Removing Regex check for now.
      //      if(validIpRegex.test(value)) {
            updateAndStoreUserEnteredIpAddress(value);
            hideIpAddressOverlay();
      //      }
      //      else {
      //        ipAddressErrorField.classList.remove('hidden');
      //      }
          return false;
        };
        ipOverlayButton.addEventListener('click', toggleOverlay);
        ipOverlayButton.addEventListener('mouseover', showOverlay);
        ipOverlay.addEventListener('mousedown', handleOverlayClose);
        ipOverlay.addEventListener('touchstart', handleOverlayClose);
      
        ipIncorrectButton.addEventListener('click', toggleIpAddressOverlay);
        ipAddressInput.addEventListener('keyup', function(event) {
          if(event.keyCode === 13) {
            handleIpAddressInputSubmit(event);
          }
        });
        ipAddressInputSubmit.addEventListener('click', handleIpAddressInputSubmit);
        ipAddressOverlay.addEventListener('mousedown', handleIpAddressOverlayClose);
        ipAddressOverlay.addEventListener('touchstart', handleIpAddressOverlayClose);
      
        registerIpChangeListener(fillInIpSuggestions, true);
      
      }(this, document));
      
      </script>
      
    </div>
    <div id="server-version-field" class="small-font-size">
      <span class="black-text">Red5 Pro Server Version</span>&nbsp;&nbsp;<span class="red-text">5.4.0.b301-release</span>
    </div>
    <div class="container main-container clear-fix">
      <div id="menu-section">
        <!-- view jsp_header to view variables used in this page -->
        <div class="menu-content">
          <ul class="menu-listing">
            <li><a class="red-text menu-listing-internal" href="/">Welcome</a></li>
            <li><a class="red-text menu-listing-internal" href="/live">Live Streaming</a></li>
              <ul class="menu-sublisting">
                <li><a class="menu-broadcast-link red-text menu-listing-nested" href="/live/broadcast.jsp?host=<%= ip %>">Broadcast</a></li>
                <li><a class="red-text menu-listing-nested" href="/live/subscribe.jsp?host=<%= ip %>">Subscribe</a></li>
                <li><a class="red-text menu-listing-nested" href="/live/playback.jsp?host=<%= ip %>">VOD Playback</a></li>
        <!--         <li><a class="red-text menu-listing-nested" href="/live/twoway.jsp">Two-Way Streaming Example</a></li> -->
              </ul>
            <li><a class="red-text menu-listing-internal" href="/secondscreen">Second Screen</a></li>
              <ul class="menu-sublisting">
                  <li><a class="red-text menu-listing-nested" href="/secondscreen/hosts/html">HTML Controller</a></li>
                  <li><a class="red-text menu-listing-nested" href="/secondscreen/hosts/gamepad">Gamepad Controller</a></li>
                  <li><a class="red-text menu-listing-nested" href="/secondscreen/hosts/dpad">DPAD Controller</a></li>
              </ul>
            <li><a class="red-text menu-listing-internal" href="/streammanager">Stream Manager</a></li><li><a class="red-text menu-listing-internal" href="/api"></a></li><li><a class="red-text menu-listing-internal" href="/bandwidthdetection"></a></li><li><a class="red-text menu-listing-internal" href="/webrtcexamples">Red5 Pro HTML SDK Testbed</a></li>
          </ul>
          <ul class="menu-listing">
            <li><a class="red-text menu-listing-external" href="http://red5pro.com" target="_blank">&gt;&nbsp;Red5 Pro Site</a></li>
            <li><a class="red-text menu-listing-external" href="http://red5pro.com/docs" target="_blank">&gt;&nbsp;Red5 Pro Docs</a></li>
            <li><a class="red-text menu-listing-external" href="http://account.red5pro.com" target="_blank">&gt;&nbsp;Red5 Pro Accounts</a></li>
            <li><a class="red-text menu-listing-external" href="http://github.com/red5pro" target="_blank">&gt;&nbsp;Red5 Pro Github</a></li>
          </ul>
        <hr>
          <ul class="menu-listing">
            <li><a class="red-text menu-listing-external" href="https://red5pro.zendesk.com?origin=webapps" target="_blank">Looking For Help?</a></li>
          </ul>
          <script>
            (function(window, document) {
              var className = 'menu-broadcast-link';
              function handleLiveIpChange(value) {
                var elements = document.getElementsByClassName(className);
                var length = elements ? elements.length : 0;
                var index = 0;
                for(index = 0; index < length; index++) {
                  elements[index].href = ['/live/broadcast.jsp?host', value].join('=');
                }
              }
              window.r5pro_registerIpChangeListener(handleLiveIpChange);
             }(this, document));
          </script>
        </div>
      </div>
      <div id="content-section">
        <div>
          <div class="clear-fix">
            <p class="left">
                <a class="red5pro-header-link" href="/">
                  <img class="red5pro-logo-page" src="images/red5pro_logo.svg">
               </a>
            </p>
          </div>
          <h2 class="tag-line">VIDEO ON DEMAND PLAYBACK FOR ANY SCREEN</h2>
        </div>
        <div id="live-page-subcontent" class="clear-fix">
          <div id="live-image-container">
            <img id="live-page-img" src="images/red5pro_live_streaming.png">
          </div>
        </div>
        <div class="content-section-story">
          <div>
            <p>Below you will find the list of recorded video to stream.</p>
            <p>If a stream is available to playback, you can select to view in browser on this page or a seperate window using the <strong>Red5 Pro HTML SDK</strong>.</p>
            <div id="available-streams-listing" class="menu-content streaming-menu-content">
              <h3 class="no-streams-entry">Requesting files...</h3>
            </div>
            <p>You can Record a Broadcast session by visiting the <a class="broadcast-link link" href="broadcast.jsp?host=<%=ip%>" target="_blank">Broadcast page</a> and checking the <b>Enable Recording</b> button.</p>
            <p><em>Once a Broadcast session is started and stopped, the Video On Demand</em> (VOD) <em>Recording will be available. Return to this page to see the stream name listed.</em></p>
          </div>
          <hr class="top-padded-rule" />
          <h3><a class="link" href="https://www.red5pro.com/docs/streaming/" target="_blank">Streaming SDKs</a></h3>
          <p>You can download the Streaming SDKs from your <a class="link" href="http://account.red5pro.com/download" target="_blank">Red5 Pro Accounts</a> page.</p>
          <p>Please visit the online <a class="link" href="https://www.red5pro.com/docs/streaming/" target="_blank">Red5 Pro Documentation</a> for further information about integrating the streaming SDKs into your own native application!</p>
          <hr class="top-padded-rule" />
          <div>
            <h3>Example Native Applications</h3>
            <h4>You will need a native application integrated with the Red5 Pro SDKs installed on your favorite device in order to broadcast and consume live streams and experience Red5 Pro Second Screen.</h4>
            <p>You can find the following Open Source native application examples on our <a class="link" href="https://github.com/red5pro" target="_blank">Github</a>:</p>
            <div class="menu-content">
              <ul class="menu-listing application-listing">
                <li><a class="red-text" href="https://github.com/red5pro/streaming-ios" target="_blank">&gt;&nbsp;Red5 Pro iOS Examples</a></li>
                <li><a class="red-text" href="https://github.com/red5pro/streaming-android" target="_blank">&gt;&nbsp;Red5 Pro Android Examples</a></li>
              </ul>
            </div>
            <p>Follow the project setup and build instructions in each project to easily create Red5 Pro native clients to begin using the above server applications!</p>
          </div>
          
          <hr class="top-padded-rule" />
          <div>
            <h3>API Documentation</h3>
            <p>To find more in-depth information about Red5 Pro Server and the server and mobile SDKs, please visit <a class="link" href="http://red5pro.com/docs/">http://red5pro.com/docs/</a>.</p>
          </div>
          
        </div>
      </div>
    </div>
    <div class="footer">
      <div>
        <a id="footer-email" href="https://red5pro.zendesk.com?origin=webapps" target="_blank">
          <span class="red-text email-header">Looking for something else?</span>
          <br>
          <br>
          <span id="footer-email-lead" class="black-text">We're here to help!</span>      <span class="red-text">Get in touch</span>
        </a>
      </div>
      <br>
      <hr>
      <p class="footer-copyright">
        <span>Copyright &copy; 2015,</span>&nbsp;
            <img class="red5pro-logo-footer" src="images/red5pro_logo.svg">
      </p>
    </div>
    <script src="lib/jquery-1.12.4.min.js"></script>
    <script src="lib/red5pro/red5pro-sdk.min.js"></script>
    <script src="script/r5pro-ice-utils.js"></script>
    <script>
      // Put server vars globally.
      var viewTech = "<%=tech%>";
      if (viewTech && viewTech !== 'null') {
        window.r5proViewTech = viewTech;
      }
      window.targetHost = "<%=ip%>";
      window.r5proIce = window.determineIceServers('<%=ice%>');
   </script>
    <script src="script/r5pro-playback-failover.js"></script>
    <script>
      // Filtering HLS playback using servlet.
      (function (window, document, $) {
       'use strict';

       var protocol = "<%=protocol%>";
       var ip = "<%=ip%>";
       var port = window.location.port ? window.location.port : (protocol === 'https' ? 443 : 80);

       var httpRegex = /^http/i;
       var baseUrl = protocol + '://' + ip + ':' + port + '/live';
       var mediafilesServletURL = [baseUrl, 'mediafiles'].join('/');
       var playlistServletURL = [baseUrl, 'playlists'].join('/');
       var store = {}; // name: {name:string, url:string, formats:[hls|flv]}

       var parseItem = function (item) {
          var itemName = item.name; // item.name.substring(0, item.name.lastIndexOf('.'));
          var itemUrl = httpRegex.test(item.url) ? item.url : [baseUrl, item.url].join('/');
          return {
            name: itemName,
            url: itemUrl
          };
       }

       var getItemList = function (data, url, listProperty, formatType, cb) {
         var req = new XMLHttpRequest();
         req.onreadystatechange = function () {
           if (this.readyState === 4) {
             if (this.status >= 200 && this.status < 400) {
                var response = JSON.parse(this.response);
                console.log("Response: " + JSON.stringify(response, null, 2));
                var list = response.hasOwnProperty(listProperty) ? response[listProperty] : [];
                var items = [];
                var i, item, length = list.length;
                for (i = 0; i < length; i++) {
                  item = parseItem(list[i]);
                  if (!data.hasOwnProperty(item.name)) {
                    data[item.name] = {
                      name: item.name,
                      urls: {}
                    };
                  }
                  data[item.name].urls[formatType] = item.url;
                }
                cb(data);
            }
            else if (this.status === 0 || this.status > 400) {
              cb(data);
            }
          }
        }
        req.onerror = function () {
          cb(data);
        }
        req.timeout = 60000 * 5; // 5 minutes
        req.open('GET', url, true);
        req.send();
      };

      var getMediafiles = function (data, cb) {
        getItemList(data, mediafilesServletURL, 'mediafiles', 'rtmp', cb);
      }

      var getPlaylists = function (data, cb) {
        var doInclude = "<%=playlistFlag%>" == "1";
        if (doInclude) {
          getItemList(data, playlistServletURL, 'playlists', 'hls', cb);
        }
        else {
          cb(data);
        }
      };

      var populateListing = function (data) {
        console.log("Store:\r\n" + JSON.stringify(data, null, 2));

        var $container = $('#available-streams-listing');
        var innerContent = '';
        var getStreamListItem = function (item) {
          var json = encodeURIComponent(JSON.stringify(item));
          var streamName = item.name;
          var urls = item.urls;
          var html = "<li data-stream=\"" + streamName + "\" data-streamitem=\"" + json + "\" class=\"stream-listing\">\r\n" +
                  "<h2 class=\"stream-header\">" + streamName + "</h2>\r\n" +
                  "<p>\r\n" +
                    "<a class=\"medium-font-size subscriber-link link red-text\" style=\"cursor: pointer;\" onclick=\"invokeViewStream('" + streamName + "'); return false;\">\r\n" +
                      "View <strong>" + streamName + "</strong>'s stream on this page." +
                    "</a>\r\n" +
                  "</p>\r\n" +
                  "<hr>\r\n" +
                  "<p>\r\n" +
                    "<span class=\"black-text\">or,&nbsp;&nbsp;<a class=\"subscriber-link link red-text\" style=\"cursor: pointer;\" onclick=\"invokeViewPageStream('" + streamName + "'); return false;\">Open in another window</a></span>\r\n" +
                  "</p>\r\n" +
                "</li>";
          return html;
        };

        for (var key in data) {
          innerContent += getStreamListItem(data[key]);
        }

        if (innerContent.length > 0) {
          innerContent = '<ul class="stream-menu-listing">' + innerContent + '</ul>';
          $container.html(innerContent);
        }
        else {
          $container.html('<h3 class="no-streams-entry">No recordings found</h3>');
        }
      };

      getMediafiles(store, function(data) {
        getPlaylists(data, function(data) {
          populateListing(data);
        });
       });

      })(this, document, jQuery.noConflict());
    </script>
  </body>
</html>

