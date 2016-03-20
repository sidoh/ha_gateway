# ha_gateway
This is a tiny home automation REST gateway. It currently controls:

1. Lights using [ledenet_api](http://github.com/sidoh/ledenet_api) and [limitless-led](https://github.com/hired/limitless-led).
2. TV using [bravtroller](http://github.com/sidoh/bravtroller).
3. Kodi using UPnP.
4. Foscam IP camera.

## Configuration

Configurations for this server are located in `./config/ha_gateway.yml`. You can copy the example config from `./config/ha_gateway.yml.example`.

There are a few different endpoints which represent types of things: light, switch, camera, etc. You can configure multiple devices under each type using different drivers. For example, the following will configure an LED strip controlled by `ledenet_api`:

```yaml
lights:
  leds:
    driver: ledenet
    params:
      host: ledenet1
```

This configures ha_gateway to respond to `POST /lights/leds`. Parameters are documented in a later section.

Please see [this blog post](http://blog.christophermullins.net/2015/10/17/cheap-alternative-to-phillips-hue-led-strip/) for more details on the overall setup.

## Using

You can start or stop the server with the provided scripts in `./bin`. Configure the port and device binding in `./bin/run.sh`.

`bin/run.sh` will start the process in the foreground. `bin/start` will daemonize the process, redirecting output to `log/ha_gateway.log`. `bin/stop` kills a daemonized process.

## Security

This server uses [HMAC](https://en.wikipedia.org/wiki/Hash-based_message_authentication_code) signatures to verify that the caller is authorized. A shared secret is used to sign a random parameter and the timestamp. A valid request must include the following headers:

1. `X-Signature-Payload`: a random string. I used UUIDs.
2. `X-Signature-Timestamp`: a UNIX epoch timestamp.
3. `X-Signature`: the HMAC signature of `payload + timestamp`.

The value of `X-Signature` is checked against the computed signature from the other headers. If this signature is not present or does not match, the server returns a `403: Unauthorized` error.

To prevent reply attacks, the timestamp specified in `X-Signature-Timestamp` must be no older than 20 seconds. This requires that servers involved have up to date clocks.

## Endpoints

By default, this server starts on port 8000 (configure in `config.ru`). Supported endpoints:

1. `POST /lights/:light_name`
2. `POST /switches/:switch_name`
4. `POST /camera/:camera_name`
5. `GET /camera/:camera_name/snapshot.jpg`
5. `GET /camera/:camera_name/status.json`
6. `GET /camera/:camera_name/stream.mjpeg`

## Supported parameters 

### POST /lights/:light_name

1. `r`, `g`, `b` (all must be present to have an effect). Sets RGB value for LEDs. Range for each parameter should be [0,255].
2. `status`. Sets on/off status. Supported values are "on" and "off".
3. `level`. Sets the level/luminosity. Converts current color to HSL, adjusts level, and re-converts to RGB. Range should be [0,100].

### POST /switch/:switch_name

1. `status`. Can be `on` or `off`.

### POST /camera/:camera\_name

1. `recording`. Can be `true` or `false`. Enables or disables recording, respectively.
2. `preset`. Sets the position preset. These can be defined in the camera UI. Value should be the name of the preset.
3. `irMode`. Sets infrared LEDs to auto mode when `0`, manual mode when `1`.
4. `ir`. Turns on the infrared LEDs when `1`, off when `0`. Requires `irMode` to be set to `1`.
5. `remoteAccess`. Enables or disables the P2P feature required to access the camera remotely (though the foscam app).

### GET /camera/:camera\_name/snapshot.jpg

1. `rotate`. Rotates the image by the provided number of degrees. Requires imagemagick's `convert` to be accessible via commandline.

### GET /camera/:camera\_name/stream.mjpeg

1. `length`. Limits the length of the stream to the provided value (in seconds).

#### Example

The following example was executed with security features disabled (commented out):

```
$ curl -X POST -d'status=on' -vvv http://localhost:8000/lights/leds
* Hostname was NOT found in DNS cache
*   Trying ::1...
* Connection failed
* connect to ::1 port 8000 failed: Connection refused
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 8000 (#0)
> POST /lights/leds HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost:8000
> Accept: */*
> Content-Length: 9
> Content-Type: application/x-www-form-urlencoded
>
* upload completely sent off: 9 out of 9 bytes
< HTTP/1.1 200 OK
< Content-Type: text/html;charset=utf-8
< Content-Length: 17
< X-XSS-Protection: 1; mode=block
< X-Content-Type-Options: nosniff
< X-Frame-Options: SAMEORIGIN
< Connection: keep-alive
* Server thin is not blacklisted
< Server: thin
<
* Connection #0 to host localhost left intact
{"success": true}%
```
