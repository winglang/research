# Slack bot - What happened today till last time I checked?

This Slack bot is a slash command that will return a list of all the commits since the last time the user checked.

## Usage

- `/wing releases` - Returns a list of all the commits since the last time the user checked.
- `/wing reset <git-ref>` - Resets the last time the user checked to the given git reference.
- `/wing commits-since <git-ref>` - Returns a list of all the commits since the given git reference.

## Installation

- Create a new slack app at `https://api.slack.com/apps`
- Add a new slash command at `https://api.slack.com/apps/<app-id>/slash-commands`
- Name the command `/wing`
- Set the request URL to `https://<wing-server>/command`
- Got to a slack channel and type `/wing releases` to test it out.

## Team

@raphaelmanke

## Demo Video

[TBD](https://www.youtube.com)

## Issues

- [#2271](https://github.com/winglang/wing/issues/2271) - static api port
- [#2272](https://github.com/winglang/wing/issues/2272) - wrong content-type
- [#2078](https://github.com/winglang/wing/issues/2078) - support urlencoded body fixed by (#2079)
- [#178](https://github.com/winglang/wing/issues/178) - lot of s3 buckets fixed by (#2111)
- [#2048] (https://github.com/winglang/wing/issues/2084) - ngrok in extern
