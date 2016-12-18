# ha_gateway
This is a tiny home automation REST gateway. It supports the following types of devices:

1. RGB lights (off/on, level, r/g/b color)
2. Switches (off/on)
3. IP cameras

There are several *drivers* for each type of device. For example, there's a driver for MiLight bulbs and foscam IP cameras.

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

This configures ha_gateway to respond to `PUT /lights/leds`. Parameters are documented in a later section.

Please see [this blog post](http://blog.christophermullins.net/2015/10/17/cheap-alternative-to-phillips-hue-led-strip/) for more details on the overall setup.

## Installing

First, check out the project:

```
git clone git://github.com/sidoh/ha_gateway.git 
cd ha_gateway
```

Copy or move the configuration example over and edit it to your liking:

```
cp config/ha_gateway.yml.example config/ha_gateway.yml
```

You can start or stop the server with the provided scripts in `./bin`. Configure the port and device binding in `./bin/run.sh`.

`bin/run.sh` will start the process in the foreground. `bin/start` will daemonize the process, redirecting output to `log/ha_gateway.log`. `bin/stop` kills a daemonized process.

## Security

This server uses [HMAC](https://en.wikipedia.org/wiki/Hash-based_message_authentication_code) signatures to verify that the caller is authorized. A shared secret is used to sign a random parameter and the timestamp. A valid request must include the following headers:

1. `X-Signature-Payload`: a random string. I used UUIDs.
2. `X-Signature-Timestamp`: a UNIX epoch timestamp.
3. `X-Signature`: the HMAC signature of `payload + timestamp`.

The value of `X-Signature` is checked against the computed signature from the other headers. If this signature is not present or does not match, the server returns a `403: Unauthorized` error.

To prevent reply attacks, the timestamp specified in `X-Signature-Timestamp` must be no older than 20 seconds. This requires that servers involved have up to date clocks.

## Drivers

Each device type has one ore more supported drivers. Every device of the same type supports the same interface, and the driver defines how that interface is implemented. You can find documentation either in the example configuration file or in the driver classes themselves.

### Light

1. LEDENET Magic UFO. Uses [ledenet_api](https://github.com/sidoh/ledenet_api).
2. MiLight (Limitless LED) Bulbs. Uses [limitless-led](https://github.com/hired/limitless-led)

### Switch

1. Bravtroller. Control Sony Bravia TVs. Uses [bravtroller](https://github.com/sidoh/bravtroller).
2. UPnP. Define custom UPnP actions for both `on` and `off` actions. There's an example that controls Kodi in the example config.

### Camera

1. Foscam 98 series.
2. Amcrest 721 series.

### Meta-Drivers

You can use these to chain together drivers in an interesting way:

1. `noop`: do nothing.
2. `composite`: control many devices from a single, aggregate device. You could use this, for example, if you wanted a master endpoint that controls all of your lights.
3. `demux`: redirect each action to its own driver. Maybe you want `on` to do nothing and `off` to use UPnP to stop whatever Kodi is playing, for example.

## Endpoints

By default, this server starts on port 8000 (configure in `config.ru`). Supported endpoints:

1. `PUT /lights/:light_name`
2. `PUT /switches/:switch_name`
4. `PUT /cameras/:camera_name`
5. `GET /cameras/:camera_name/snapshot.jpg`
5. `GET /cameras/:camera_name/status.json`
6. `GET /cameras/:camera_name/stream.mjpeg`
7. `GET /cameras/:camera_name/presets`
8. `POST /cameras/:camera_name/presets`
9. `GET /cameras/:camera_name/presets/:preset_name`
10. `POST /cameras/:camera_name/move`

## Supported parameters 

### PUT /lights/:light_name

1. `r`, `g`, `b` (all must be present to have an effect). Sets RGB value for LEDs. Range for each parameter should be [0,255].
2. `status`. Sets on/off status. Supported values are "on" and "off".
3. `level`. Sets the level/luminosity. Converts current color to HSL, adjusts level, and re-converts to RGB. Range should be [0,100].

### PUT /switches/:switch_name

1. `status`. Can be `on` or `off`.

### PUT /cameras/:camera\_name

1. `recording`. Can be `true` or `false`. Enables or disables recording, respectively.
2. `preset`. Sets the position preset. These can be defined in the camera UI. Value should be the name of the preset.
3. `irMode`. Sets infrared LED mode. Can be `auto`, `on`, or `off`.
4. `remoteAccess`. Enables or disables the P2P feature required to access the camera remotely (though the foscam app).
5. `motionDetection[enabled]`. Enables or disables motion detection.
6. `motionDetection[sensitivity]`. Sets motion detection sensitivity (on a scale from 0 to 100, 0 being least sensitive).

### GET /cameras/:camera\_name/snapshot.jpg

1. `rotate`. Rotates the image by the provided number of degrees. Requires imagemagick's `convert` to be accessible via commandline.

### GET /cameras/:camera\_name/stream.mjpeg

1. `length`. Limits the length of the stream to the provided value (in seconds).

### POST /cameras/:camera\_name/presets

1. `name`. Name of the preset.

### POST /camera/:camera\_name/move

1. `direction`. One of Left, Right, Up, or Down. Some cameras support mixed directions.
2. `amount`. Amount to move. Scale between 0 and 100.

#### Example

The following example was executed with security features disabled (commented out):

```
$ curl -vvv -X PUT -d'status=on'  http://localhost:8000/lights/leds
* Hostname was NOT found in DNS cache
*   Trying ::1...
* Connection failed
* connect to ::1 port 8000 failed: Connection refused
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 8000 (#0)
> PUT /lights/leds HTTP/1.1
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

## SmartThings

HaGateway allows you to control devices and execute routines within SmartThings. This allows you to integrate custom event controllers (like Amazon Dash buttons) with SmartThings.

To use this integration, you'll need to do a few things:

1. Set up a [SmartApp](http://docs.smartthings.com/en/latest/smartapp-developers-guide/). I'd recommend [this one](https://gist.github.com/sidoh/da36d2c1099910ef38a6021dc39a61a4).
2. Enable OAuth on that app, and fill the Client ID and Client Secret in HaGateway's config.
3. Run through OAuth by navigating to http://<hagatewayurl>/smartthings/authorize. You might be prompted to select which devices you'd like to enable control of.

You can then make use of the following endpoints:

### GET /smartthings/devices

Returns a JSON object of devices. Structure is: `key -> data`, where key is a UUID used to address the device, and data includes the name and current status of the device.

### PUT /smartthings/devices/:device_id

Changes the status of the specified device. Only supported parameter is `command`, which must be passed as the query string in the URL due to a bug in SmartThings. Supported values are `on`, `off`, and `toggle`.

### GET /smartthings/routines

Gets a list of routines.

### GET /smartthings/routines/:routine

Executes the specified routine. Normalize by:

* Removing non-alphanumeric characters
* Replacing spaces with underscores
* Downcasing

So "Good Night!" becomes "good_night".

## Listeners

HaGateway runs a separate process that listens for events, and allows configurable actions to be executed when events arrive. You could use this, for example, to run some SmartThings routine when an Amazon Dash button is pressed. 

Listens run in a separate process for a few reasons:

* They're not really a part of the REST server, so it made sense to isolate them.
* The Amazon Dash hack typically requires packet sniffing, which usually means the process needs to run as root. Wanted to reduce the amount of code running in a privileged environment.

For examples and documentation, see the example configuration file.
