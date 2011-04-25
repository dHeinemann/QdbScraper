#!/usr/bin/Perl

# QdbScraper.pl
# A QdbS quote database scraper (see www.qdbs.org)
# Licensed under the New BSD License
#
# Copyright (c) 2011 David Heinemann. All Rights Reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
#   * The name of the author may not be used to endorse or promote
#     products derived from this software without specific prior written
#     permission.
# 
# THIS SOFTWARE IS PROVIDED BY DAVID HEINEMANN "AS IS" AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

use warnings;
use strict;
use HTML::TokeParser;
use WWW::Mechanize;
use Scalar::Util qw(looks_like_number);
use Getopt::Std;

our ($opt_d, $opt_f, $opt_p, $opt_s, $opt_w);
getopt('dpsw');
getopts('f');
#TODO: Single-file mode - Appends all quotes to each other into a single file (-c for concatenate?)
#TODO: Fortune cookie only mode

my $baseUrl       = "";
my $url           = "";
my $directory     = "";
my $quoteList     = "quotelist.txt";
my $pageNo        = 1;
my $lastPageNo    = 9000;
my $wait          = 2;
my $quoteCounter  = 0;
my $fortune       = 0;

if ($opt_d)
{
	$directory  = $opt_d;
	print("Directory manually set to '$directory'.\n\n");
}

if ($opt_f and $opt_f == 1)
{
	$fortune = 1;
}

if ($opt_p)
{
	if (looks_like_number($opt_p))
	{
		$lastPageNo = $opt_p;
		print("Number of pages manually set to $lastPageNo.\n\n");
	}
	else
	{
		die("Invalid number of pages specified.  You gave '$opt_p'.\n");
	}
}

if ($opt_s)
{
	if (looks_like_number($opt_s))
	{
		$pageNo = $opt_s;
		print("Starting page number manually set to $pageNo.\n\n");
	}
	else
	{
		die("Invalid starting page specified.  You gave '$opt_s'.\n");
	}
}

if ($opt_w)
{
	if (looks_like_number($opt_w))
	{
		$wait = $opt_w;
		print("Wait delay manually set to $wait.\n\n");
	}
	else
	{
		die("Invalid wait delay specified.  You gave '$opt_w'.\n");
	}
}


my $instructions  = <<TEXT;
Scrape a QdbS-powered quote database.

QdbScraper.pl [-d] [-p] [-s] [-w] URL

  -d        Manually set the directory that quotes are saved into.
            (default: automatic)
  -f        Create a fortune cookie file from extracted quotes (boolean)
  -w        Manually set the wait delay (in seconds) between each page
            load. (default: 2)
  -s        Manually set the starting page. (default: 1)
  -p        Manually set the total number of pages. (default: automatic)
  URL       The URL of the QDB to be scraped.  See URL Instructions for
            more information.

URL Instructions:
  Always omit file names in the URL.
    use:        http://www.foobar.com/qdb
    instead of: http://www.foobar.com/qdb/index.php

  Always omit trailing slashes in the URL.
    use:        http://www.foobar.com/qdb
    instead of: http://www.foobar.com/qdb/
TEXT

if ($ARGV[0])
{
	$baseUrl = $ARGV[0];
	$url = $baseUrl . "/index.php?p=browse&page=";
	$directory = &urlToDirectory($baseUrl) if ($directory eq "");

	#Create $directory if it doesn't already exist
	unless (-d $directory)
	{
		mkdir("$directory") or die("Error: Couldn't create directory $directory.\n");
	}
	chdir($directory);
}
else
{
	die($instructions);
}

print("Opening $quoteList for write...\n");
open(QUOTELIST, ">$quoteList") or die("Error: Couldn't open $quoteList for writing.\n");
open(FORTUNE, ">fortune.txt") if $fortune == 1;

my $mech = WWW::Mechanize->new(agent => 'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/534.16 (KHTML, like Gecko) Chrome/10.0.634.0 Safari/534.16');

while ($pageNo <= $lastPageNo)
{
	&scanPage();
	print("Sleeping for $wait seconds...\n\n");
	sleep($wait);
}
close(QUOTELIST);
close(FORTUNE) if $fortune == 1;
print("Finished.  $quoteCounter quotes saved.\n");

sub getLastPageNo()
{
	#Searches the Browse page for the highest available page number
	my $page = HTML::TokeParser->new(\$mech->{content});
	print("Finding the total number of pages...\n");
	while (my $tag = $page->get_tag("a"))
	{
		if ($tag->[1]{title} and $tag->[1]{title} =~ m/Last Page/gi)
		{
			$lastPageNo = $tag->[1]{href};
			$lastPageNo =~ s/\D//gi;
		}
		elsif ($tag->[1]{href} and $tag->[1]{href} eq "./?1")
		{
			$lastPageNo = 1;
		}
	}

	if ($lastPageNo > 1)
	{
		print("There are $lastPageNo pages.\n\n");
	}
	elsif ($lastPageNo == 1)
	{
		print("There is $lastPageNo page.\n\n");
	}
}

sub scanPage()
{
	#Scan the current page for quotes
	print("Fetching page $pageNo ($url$pageNo)...\n");
	$mech->get("$url" . "$pageNo");

	&getLastPageNo() if $lastPageNo == 9000;
	my $page = HTML::TokeParser->new(\$mech->{content});

	print("Looking for quotes...\n");
	while (my $tag = $page->get_tag("td"))
	{
		my $id;
		my $text;
		if ($tag->[1]{class} and $tag->[1]{class} eq "title")
		{
			$tag = $page->get_tag("a");
			$id = $page->get_text("/a");
			print(QUOTELIST "$id\n");

			$tag = $page->get_tag("td");
			if ($tag->[1]{class} and $tag->[1]{class} eq "body")
			{
				do
				{
					$text .= $page->get_trimmed_text() . "\n";
					$tag = $page->get_tag();
				} while ($tag->[0] ne "/td");

				#Remove blank lines
				#TODO: Instead, test to see if $text matches any of these, then keep iterating until it doesn't.
				for (my $i = 0; $i <= 2; $i++)
				{
					$text =~ s/^\n//gi;
					$text =~ s/\n$//gi;
					$text =~ s/\n\n//gi;
				}

				open(OUTFILE, ">$id.txt");
				print(OUTFILE "$text");
				print(FORTUNE "$text\n\n\t$baseUrl?$id\n%\n");
				close(OUTFILE);
				print("  saved #$id ($directory/$id.txt)\n");
				$quoteCounter++;
			}
			else
			{
				print("Error: Quote " . $id . "'s text was not in the expected location\n");
				print("Skipping $id...\n");
			}
		}
	}
	print("Page $pageNo done.\n\n");
	$pageNo++;
}

sub urlToDirectory()
{
	#Turn the URL into a filename-friendly format
	#Removes "http://", "www." and replace forward slashes with dashes
	#to ensure there are no issues with invalid characters
	my $new = $_[0];
	$new =~ s/http:\/\///gi;
	$new =~ s/www.//gi;
	$new =~ s/\//-/gi;
	return $new;
}
