#!/usr/bin/env perl

#
# Script that uses Microsoft Translator for text translation.
#
# Copyright (C) 2012 - 2014, Lefteris Zafiris <zaf.000@gmail.com>
#
# This program is free software, distributed under the terms of
# the GNU General Public License Version 2.
#
# In order to use this script you have to subscribe to the Microsoft
# Translator API on Azure Marketplace:
# https://datamarket.azure.com/developer/applications/
# and register your application with Azure DataMarket:
# https://datamarket.azure.com/developer/applications/
#

use warnings;
use strict;
use Getopt::Std;
use URI::Escape;
use LWP::UserAgent;

# --------------------------------------- #
# Here you can assing your client ID and  #
# client secret from Azure Marketplace.   #
my $clientid = "";
my $clientsecret = "";
# --------------------------------------- #

my %options;
my $input;
my $in_lang;
my $out_lang;
my $atoken;
my $url;
my $ua;
my $use_ssl = 0;
my $timeout = 15;
my $content = "text/plain";
my $host    = "api.microsofttranslator.com/V2/Http.svc";

VERSION_MESSAGE() if (!@ARGV);

getopts('o:l:t:f:c:hqev', \%options);

# Dislpay help messages #
VERSION_MESSAGE() if (defined $options{h});

($clientid, $clientsecret) = split(/:/, $options{c}, 2) if (defined $options{c});
$atoken = get_access_token();

if (!$atoken) {
	say_msg("You must have a client ID from Azure Marketplace to use this script.");
	exit 1;
}
# set SSL encryption #
if (defined $options{e}) {
	$use_ssl = 1;
}

lang_list() if (defined $options{v});

# check if language settings are valid #
if (defined $options{l}) {
	if ($options{l} =~ /[a-zA-Z\-]{2,}/) {
		$in_lang = $options{l};
	} else {
		say_msg("Invalid input language setting. Using auto-detect.");
	}
}

if (defined $options{o}) {
	if ($options{o} =~ /[a-zA-Z\-]{2,}/) {
		$out_lang = $options{o};
	} else {
		say_msg("Invalid output language setting. Aborting.");
		exit 1;
	}
} else {
	print "Performing language detection.\n" if (!defined $options{q});
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
	$_ = uri_escape($_);
}

# Initialise User angent #
if ($use_ssl) {
	$url = "https://" . $host;
	$ua  = LWP::UserAgent->new(ssl_opts => {verify_hostname => 1});
} else {
	$url = "http://" . $host;
	$ua  = LWP::UserAgent->new;
}
$ua->env_proxy;
$ua->timeout($timeout);

if ($in_lang && $out_lang) {
	$url .= "/Translate?text=$input&from=$in_lang&to=$out_lang&contentType=$content&appid=$atoken";
} elsif (!$in_lang && $out_lang) {
	$url .= "/Translate?text=$input&to=$out_lang&contentType=$content&appid=$atoken";
} elsif (!$out_lang) {
	$url .= "/Detect?text=$input&appid=$atoken";
}

my $request = HTTP::Request->new('GET' => "$url");
my $response = $ua->request($request);
if (!$response->is_success) {
	say_msg("Failed to fetch translation data.");
	exit 1;
} else {
	$response->content =~ /<string.*>(.*)<\/string>/;
	print "$1\n";
}
exit 0;

sub get_access_token {
# Obtaining an Access Token #
	my $tk_ua = LWP::UserAgent->new(ssl_opts => {verify_hostname => 1});
	$tk_ua->timeout($timeout);
	my $response = $tk_ua->post(
		"https://datamarket.accesscontrol.windows.net/v2/OAuth2-13/",
		[
			client_id     => $clientid,
			client_secret => $clientsecret,
			scope         => 'http://api.microsofttranslator.com',
			grant_type    => 'client_credentials',
		],
	);
	if ($response->is_success) {
		$response->content =~ /^\{"token_type":".*","access_token":"(.*?)","expires_in":".*","scope":".*"\}$/;
		my $token = uri_escape("Bearer $1");
		return("$token");
	} else {
		say_msg("Failed to get Access Token.");
		return("");
	}
}

sub lang_list {
# Display the list of supported languages, we can translate between any two of these languages #
	if ($use_ssl) {
		$url = "https://" . $host;
		$ua  = LWP::UserAgent->new(ssl_opts => {verify_hostname => 1});
	} else {
		$url = "http://" . $host;
		$ua  = LWP::UserAgent->new;
	}
	$ua->env_proxy;
	$ua->timeout($timeout);
	my $request = HTTP::Request->new('GET' => "$url/GetLanguagesForTranslate?appid=$atoken");
	my $response = $ua->request($request);
	if ($response->is_success) {
		print "Supported languages list:\n",
			join("\n", grep(/[a-zA-Z\-]{2,}/, split(/<.+?>/, $response->content))), "\n";
	} else {
		say_msg("Failed to fetch language list.");
	}
	exit 1;
}

sub say_msg {
# Print messages to user if 'quiet' flag is not set #
	my @message = @_;
	warn @message if (!defined $options{q});
	return;
}

sub VERSION_MESSAGE {
# Help message #
	print "Text translation using Microsoft Translator API.\n\n",
		"In order to use this script you have to subscribe to the Microsoft\n",
		"Translator API on Azure Marketplace:\n",
		"https://datamarket.azure.com/developer/applications/\n",
		"Existing API Keys from http://www.bing.com/developers/appids.aspx\n",
		"still work but they are considered deprecated and this method is no longer supported.\n\n",
		 "Supported options:\n",
		 " -t <text>      text string for translation\n",
		 " -f <file>      text file to translate\n",
		 " -l <lang>      specify the input language (optional)\n",
		 " -o <lang>      specify the output language\n",
		 " -c <clientid>  set the Azure marketplace credentials (clientid:clientsecret)\n",
		 " -q             quiet (Don't print any messages or warnings)\n",
		 " -e             use SSL for encryption\n",
		 " -h             this help message\n",
		 " -v             suppoted languages list\n\n",
		 "Examples:\n",
		 "$0 -o fr -t \"Hello world\"\n\tTranslate \"Hello world\" in French.\n",
		 "$0 -t \"Salut tout le monde\"\n\tDetect the language of the text string.\n\n";
	exit 1;
}
