#!/usr/bin/env perl

#
# Script that uses Microsoft Translator for text translation.
#
# In order to use this script an API Key (appid)
# from http://www.bing.com/developers/appids.aspx is needed.
#
# Copyright (C) 2012, Lefteris Zafiris <zaf.000@gmail.com>
#
# This program is free software, distributed under the terms of
# the GNU General Public License Version 2.
#

use warnings;
use strict;
use Getopt::Std;
use CGI::Util qw(escape);
use LWP::UserAgent;

# --------------------------------------- #
# Here you can assign your App ID from MS #
my $appid   = "";
# --------------------------------------- #
my %options;
my $input;
my $in_lang;
my $out_lang;
my $ua;
my $request;
my $response;
my $timeout = 10;
my $content = "text/plain";
my $url     = "http://api.microsofttranslator.com/V2/Http.svc";

VERSION_MESSAGE() if (!@ARGV);

getopts('o:l:t:f:i:hqv', \%options);

# Dislpay help messages #
VERSION_MESSAGE() if (defined $options{h});

$appid = $options{i} if (defined $options{i});
if (!$appid) {
	say_msg("You must have an App ID from Microsoft to use this script.");
	exit 1;
}

lang_list() if (defined $options{v});

# check if language settings are valid #
if (defined $options{l}) {
	if ($options{l} =~ /[a-zA-Z\-]*?/) {
		$in_lang = $options{l};
	} else {
		say_msg("Invalid input language setting. Using auto-detect.");
	}
}

if (defined $options{o}) {
	$out_lang = $options{o} if ($options{o} =~ /[a-zA-Z\-]*?/);
} else {
	say_msg("Invalid output language setting. Aborting.");
	exit 1;
}

# Get input text #
if (defined $options{t}) {
	$input = $options{t};
} elsif (defined $options{f}) {
	if (open(my $fh, "<", "$options{f}")) {
		$input = do { local $/; <$fh> };
		close($fh);
	} else {
		say_msg("Cant read file $options{f}");
		exit 1;
	}
} else {
	say_msg("No text passed for translation.");
	exit 1;
}

for ($input) {
	s/[\\|*~<>^\n\(\)\[\]\{\}[:cntrl:]]/ /g;
	s/\s+/ /g;
	s/^\s|\s$//g;
	if (!length) {
		say_msg("No text passed for translation.");
		exit 1;
	}
	$_ = escape($_);
}

$ua = LWP::UserAgent->new;
$ua->agent("Mozilla/5.0 (X11; Linux; rv:8.0) Gecko/20100101");
$ua->env_proxy;
$ua->timeout($timeout);

if ($in_lang) {
	$url .= "/Translate?text=$input&from=$in_lang&to=$out_lang&contentType=$content&appid=$appid";
} else {
	$url .= "/Translate?text=$input&to=$out_lang&contentType=$content&appid=$appid";
}
$request = HTTP::Request->new('GET' => "$url");
$response = $ua->request($request);
if (!$response->is_success) {
	say_msg("Failed to fetch translation data.");
	exit 1;
} else {
	$response->content =~ /<string.*>(.*)<\/string>/;
	print "$1\n";
}
exit 0;

sub say_msg {
# Print messages to user if 'quiet' flag is not set #
	my $message = shift;
	warn "$0: $message" if (!defined $options{q});
	return;
}

sub VERSION_MESSAGE {
# Help message #
	print "Text translation using Microsoft Translator API.\n\n",
		 "Supported options:\n",
		 " -t <text>      text string for translation\n",
		 " -f <file>      text file to translate\n",
		 " -l <lang>      specify the input language (optional)\n",
		 " -o <lang>      specify the output language\n",
		 " -i <appID>     set the App ID from MS\n",
		 " -q             quiet (Don't print any messages or warnings)\n",
		 " -h             this help message\n",
		 " -v             suppoted languages list\n\n",
		 "Examples:\n",
		 "$0 -l en -o fr -t \"Hello world\"\n Translate \"Hello world\" in French.\n\n";
	exit 1;
}

sub lang_list {
# Display the list of supported languages, we can translate between any two of these languages #
	$ua = LWP::UserAgent->new;
	$ua->agent("Mozilla/5.0 (X11; Linux; rv:8.0) Gecko/20100101");
	$ua->timeout($timeout);
	$request = HTTP::Request->new('GET' => "$url/GetLanguagesForTranslate?appid=$appid");
	$response = $ua->request($request);
	if ($response->is_success) {
		print $response->content;
		print "Supported languages list:\n",
			join("\n", grep(/[a-zA-Z\-]{2,}/, split(/<.+?>|<\/.+?>/,$response->content))), "\n";
	} else {
		say_msg("Failed to fetch language list.");
	}
	exit 1;
}
