# FIT3042 - System Tools & Programming Languages S1 2016
# Assignment 3

## Libraries
The following modules were downloaded from CPAN using the cpan command line tool:
	- Bundle::LWP
	- HTML::Tree
	- LWP:Protocol:https
	- HTML::Format

## Installation Steps

	1. Start the CPAN command line tool:
		> perl -MCPAN -eshell

		Note: first time users of this tool will need to follow the configuration
		setup process by following the instructions in the terminal.

	2. Install the modules one by one by invoking:
		cpan> install Bundle::LWP
		cpan> install HTML::Tree
		cpan> install Protocol:https
		cpan> install HTML:Format

	3. Clost the CPAN command line tool:
		cpan> exit

## Running

	1. The Perl script can be invoked from the command line as follows:
		> ./windex-build.pl <NAME> <STARTURL> <EXCLUDEFILE> [dir=<DIRECTORY> maxdepth<DEPTH>]

		Required:
			- NAME is the name of the output index file
			- STARTURL is the URL where the index starts
			- EXCLUDEFILE is the path to a file containing words not to index

		Optional:
			- DIRECTORY path to the directory to store the NAME index file
			- DEPTH is the maximum depth for the page traversal

	2. The Bash script can be invoked from the command line as follows:
		> ./windex.sh <NAME> <WORD> [<DIRECTORY>]

		Required:
			- NAME is the name of the index file
			- WORD is the indexed word that you wish to see

		Optional:
			- DIRECTORY path to the directory where the index file is stored

## Features

### Argument parsing and validation
Arguments are parsed and validated using the set_options() function. It checks that the number of arguments is as expected (3-5 inclusive), checks that the mandatory arguments are valid, and then checks for optional arguments.

NAME must have at least one word character (\w)
STARTURL must be a wikipedia page
EXCLUDEFILE must point to a plain file that exists

Optional arguments can be given in any order.

DIRECTORY must point to an existing directory. If not specified, it defaults to the current directory
DEPTH must be between 0 and 5. If it is not, then it is simply set to 3, the default value

For visibility, the options are displayed using the show_options() function before any indexing occurs.

### Building an Index

#### Overview
Indexing is done interatively using a breadth first traversal of page links. A while loop is run for each "depth" (or layer) of the link tree, up to the specified maximum depth (default 3). There are two arrays that are used to store links:
	1. @links_to_visit
	2. @links_in_next_layer

Every link in the @links_to_visit is visited and the words are indexed (the data structure used to index words is explained later) and this page URL is added to a @visited_pages array. Once all words have been indexed, all of the valid links (a "valid" link will be defined later) inside of anchor tags are collected and normalised (the kind of normalisation is described later). If a link is valid and has not been visited before, it is added to the @links_in_next_layer array.

Once all links in @links_to_visit have been visited, we have completed this "depth" level, so we move to the next depth. At the start of each depth we copy the contents of @links_in_next_layer into @links_to_visit, and then empty @links_in_next_layer.

Depth level 0 only contains the start url, so this is put in @links_to_visit at the start of the program.

Once the maximum depth has been reached, or we indexed 1000 pages, we stop indexing and write the indexed words to the specified output file.

#### Index Data Structure
The word index is a hash structure where each key is a word we have found, and the associated value is a reference to an array of URLs where that word has been found. Lookup is faster than having a simple array of words.

For each word in a page, if it is not already in the hash, then add it and the current URL. If it is already part of the hash, then just add the current URL to the correct URL array. Words that are part of the @word_blacklist array are ignored.

This gets written to the output index file using the write_to_index_file() function.

#### Excluded Words
Excluded words are defined in a *.txt file, on a single line separated by spaces. The example submitted is /exclude_files/exclude.txt. It contains the 100 most common English words (according to en.wikiepedia.org/wiki/Most_common_words_in_English).

At the start of the Perl script, this file is read in, parsed, and then stored in the @word_blacklist array.

#### URL Normalisation
Two normalisation techniques are used:

	1. URL fragment removal
		Based on the RFC 3986 specification, a fragment is the last part of a URL that starts with a '#' character.
		e.g. en.wikipedia.org/wiki/Perl#History, #History is the fragment

		When a URL is found with a fragment, then the fragment is removed before checking the @visited_pages or @links_in_next_layer arrays.

		Thus, .../wiki/Perl#History becomes .../wiki/Perl

	2. Literal-to-ASCII conversion for commas
		There were some cases where a Wikipedia URL would contain a literal ',' comma character.
		e.g. en.wikipedia.org/wiki/Broome,_Western_Australia

		This would cause problems in the Bash script, which uses the literal comma character as a delimiter. So instead of displaying:
		
		en.wikipedia.org/wiki/Broome,_Western_Australia
		
		on its own line, it would show:
		
		en.wikipedia.org/wiki/Broome
		_Western_Australia

		on two lines.

		Thus, all commas in the URL are replaced with the ASCII representation '%2C'. This replacement is only used on comma literals since we were storing URLs in a CSV format. Therefore, the replacement was critical. It can be extended to other reserved characters in the future (e.g. '!')

A technique that was attempted but was not successful was converting the URL to lowercase. This would work in most cases (so .../wiki/perl would redirect to .../wiki/Perl), however would not work for others. For example:

	'.../wiki/AWK_(programming_language)' would redirect to '.../wiki/AWK', however
	'.../wiki/awk_(programming_language)' would return a 404 error

### Showing the Index
This is done using the windex.sh Bash script as explained above.

Provided with this submission is the index file /index_files/index_1000. This contains a recent "crawl" of wikipedia starting from .../wiki/Perl.

If you wanted to search for the word 'variable', you would run:

	> ./windex.sh index_files/index_1000 variable

and get the following output:

	------ START windex.sh ------

	Valid path: "/home/nick/Desktop/FIT3042_A3/index_files/index_1000"

	variable
	https://en.wikipedia.org/wiki/Perl
	https://en.wikipedia.org/wiki/Functional_programming
	https://en.wikipedia.org/wiki/Imperative_programming
	https://en.wikipedia.org/wiki/Object-oriented_programming
	https://en.wikipedia.org/wiki/Procedural_programming
	https://en.wikipedia.org/wiki/Generic_programming
	https://en.wikipedia.org/wiki/Larry_Wall
	https://en.wikipedia.org/wiki/Type_system

	...

	https://en.wikipedia.org/wiki/Pattern_matching
	https://en.wikipedia.org/wiki/Algebraic_data_types
	https://en.wikipedia.org/wiki/Lazy_evaluation
	https://en.wikipedia.org/wiki/Tail_recursion

	------ END windex.sh ------


## Known Bugs
normalisation capitalisation