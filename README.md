# twitterer
Program for tweeting random lines from files hosted on a public GitHub repo.

## Purpose
I wanted an easy way to drip-feed my [Miscellany](https://github.com/tomonocle/miscellany/) 
files into the ether, so wrote `twitterer` to do just that.

Essentially you feed it paths to publicly accessible files on GitHub and it'll
tweet a random line from them (one tweet per file) with a link to the line on
GitHub. Optionally it can keep track of previous tweets to avoid sounding 
repetitive.

Note: source files must be in the default branch, but `twitterer` will resolve
that branch to a commit before tweeting the link.

## Installation
```
  $ gem install tc-twitterer
```

## Configuration
`twitterer` requires a configuration file to operate. An example is available on 
[GitHub](https://github.com/tomonocle/tc-twitterer/blob/master/etc/config.toml.example),
or you can follow the guide below.

### Twitter Consumer API key and secret
First you need to register a new application with Twitter.

Visit [https://apps.twitter.com/](https://apps.twitter.com/) and follow the steps.

Once you've created the app, hit _Keys and Access Tokens_ to get your... Keys
and access tokens.

Config entries:

```
twitter_consumer_key    = "012a3AbcBdefg4ChiDjklEmnF"
twitter_consumer_secret = "AaBCDEbFGcdHefIgJKhi0jLk1MNOlm2nPQoRS3pTqU4rsVtWuv"
```

### Twitter User API key and secret
On the _Keys and Access Tokens_ page for your app, scroll down to _Your Access 
Token_ and hit _Create my access token_ to create your access token.

Config entries:

```
twitter_access_token        = "012345678901234567-abAcBdeCDfEghFi0GHIJKjk9l1Lmnop"
twitter_access_token_secret = "a0AbcB1C2dDEFeGH7If3ghJK4Li15j678kMNlO9PQRmno"
```

### History file
`Twitterer` can track its past tweets if you tell it where to store them, which
prevents it from repeating itself.

Config entry:

```
history_file = "/path/to/file"
```

Note: `twitterer` will create the file, but it won't create any directories.

Note 2: history is stored in a CSV in the following format, which lets it 
double as a log.

```
timestamp,source,line
```

### Sources
Finally you need to specify the locations of the files you want to tweet from.

The following conditions apply:

- Must be hosted on GitHub
- Must be publicly accessible
- Must be in the default branch

Paths are specified in the following format: `username/repo/path/to/file.txt`

Config entry:

```
source = [
  "tomonocle/tc-twitterer/README.md",
  "tomonocle/trello-list2card/README.md",
]
```

### Final config file

```
twitter_consumer_key    = "012a3AbcBdefg4ChiDjklEmnF"
twitter_consumer_secret = "AaBCDEbFGcdHefIgJKhi0jLk1MNOlm2nPQoRS3pTqU4rsVtWuv"

twitter_access_token        = "012345678901234567-abAcBdeCDfEghFi0GHIJKjk9l1Lmnop"
twitter_access_token_secret = "a0AbcB1C2dDEFeGH7If3ghJK4Li15j678kMNlO9PQRmno"

history_file = "./var/twitterer.history"

source = [
  "tomonocle/tc-twitterer/README.md",
  "tomonocle/trello-list2card/README.md",
]
```

## Usage

```
$ twitterer -c config.toml
```

This will pull down each file in the _source_ list, pick a suitable line then tweet it in the following format:

```
<first N characters of line> <url>
```

Where `N` is defined as the maximum tweet length (which will _forever_ be 140 chars) minus the maximum URL length
from `t.co` (23 as of December 2017). 140-23 = **117**

Log output goes to `STDERR`.

### Logging
Log level can be adjusted with `-l [debug,info,warn,error,fatal]` (defaults to **warn**).

### Dry-run
Dry-run (read-only, don't tweet) can be enabled with `-d`. Note: you'll probably want to increase the log level with `-l` for this to be useful.

### Exit codes
| Code | Meaning |
|:----:|---------|
| 0    | Success (wrote output, or nothing to do) |
| 1    | Failure. Something went wrong. Always accompanied by a FATAL log message. |
