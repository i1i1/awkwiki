#!/usr/bin/awk -f
################################################################################
# parser.awk - parsing script for awkiawki
# $Id: parser.awk,v 1.6 2002/12/07 13:46:45 olt Exp $
################################################################################
# Copyright (c) 2002 Oliver Tonnhofer (olt@bogosoft.com)
# See the file `COPYING' for copyright notice.
################################################################################

BEGIN {
	pagename_re = "[[:upper:]][[:lower:]]+[[:upper:]][[:alpha:]]*"
	list["maxlvl"] = 0
	scriptname = (rewrite == "true" ? "" : ENVIRON["SCRIPT_NAME"])

	cmd = "ls " datadir
	while (cmd | getline ls_out > 0)
		if (match(ls_out, pagename_re) &&
				substr(ls_out, RSTART + RLENGTH) !~ /,v/) {
			page = substr(ls_out, RSTART, RLENGTH)
			pages[page] = 1
		}
	close(cmd)

	ctx["print_toc"] = 1
	ctx["blankln"] = 0

#	syntax["regexp"] = "handler"
	syntax["$"] = "wiki_blank"
	syntax["\\[/listcategories\\]:"] = "wiki_reference_category"
	syntax["\\[/categories\\]:"] = "wiki_format_category"
	syntax["((    )|\t)[^*+0-9-]"] = "wiki_unformatted_block_indented"
	syntax["```[[:blank:]]*$"] = "wiki_unformatted_block"
	syntax["```[[:blank:]]*[[:alnum:]]"] = "wiki_highlight_code"
	syntax["#[^#]"] = "wiki_print_pagename"
	syntax["##+"] = "wiki_print_heading"
	syntax["[*+0-9-]([^-*]|$)"] = "wiki_print_list"
	syntax["\\*\\*\\*"] = "wiki_print_hr"
	syntax["---"] = "wiki_print_hr"
	syntax["___"] = "wiki_print_hr"

#	line_syntax["regexp"] = "handler"
	str = "!?\\[[^\\[\\]]+\\]\\([^()]+\\)"
	line_syntax[str] = "wiki_format_url"

	print "<p>"
}


@include "lib.awk"
@include "plugins.awk"

{
	wiki_format_marks()
}

END {
	print "<script>\n"
	while (getline < "toc.js" > 0)
		print
	print "</script>\n"
}

function wiki_format_marks()
{
	for (i in syntax) {
		if ($0 !~ "^" i)
			continue

		str = syntax[i]
		if (@str() == 1)
			continue
		next
	}

	if (ctx["blankln"] == 1) {
		print "<p>"
		ctx["blankln"] = 0
	}

	print wiki_format_line($0)
}

function wiki_blank()
{
	ctx["blankln"] = 1
}

function wiki_reference_category(	cmd, list)
{
	cmd = "grep -wl '^[ \t]*\\[/categories\\]:.*" pagename "' " datadir "*"

	while (cmd | getline > 0) {
		if (!list) { list = 1; print "<p><ul>" }
		sub(/^.*[^\/]\//, "")
		sub(pagename_re, "<li><a href=\""(rewrite == "true" ? "" : scriptname)"/&\">&</a></li>")
		print
	}

	if (list)
		print "</ul>"

	close(cmd)
}

function wiki_format_category(	tmp)
{
	print "<br><hr>"

	sub("^\\[/categories\\]:", "")
	split($0, sa, "|")

	tmp = ""

	for (i = 1; i <= arrlen(sa); i++) {
		sa[i] = strip_spaces(sa[i])
		if (sa[i] ~ pagename_re)
			tmp = tmp " | " page_ref_format(sa[i])
		else
			tmp = tmp " | " sa[i]
	}

	$0 = substr(tmp, 4)
	print
}

# For code highlighting in
# ``` langname
# ```
function wiki_highlight_code(		ex)
{
	sub(/^```/, "");
	sub(/^ */, "");
	sub(/ *$/, "");
	langname = tolower($0)

	ex = 0
	tmp = ""

	if (langname in syntaxlang) {
		cmd = syntaxlang[langname]
		@cmd()
		return
	}

	if (getline <= 0)
		ex = 1

	while ($0 !~ /^```/ && !ex) {
		tmp = tmp "\n" $0
		if (getline <= 0)
			ex = 1
	}

	tmp = substr(tmp, 2)
	fname = mktemp("")
	print tmp > fname
	close(fname)

	cmd = "./highlight/highlighter.py " fname " " langname
	while (cmd | getline out)
		print out
	close(cmd)
	rmfile(fname)

	if (ex)
		exit(1)
}

# For unformated data which is 4 spaces or tab indented
function wiki_unformatted_block_indented()
{
	print "\n<div class=\"mw-highlight\">"
	print "<pre>"

	while (/^((    )|\t)/) {
		sub(/^((    )|\t)/, "")
		print html_ent_format($0)
		if (getline <= 0) {
			print "</pre>"
			print "</div>"
			exit(1)
		}
	}

	print "</pre>"
	print "</div>"
}

# For unformated data in:
# ```
# ```
function wiki_unformatted_block()
{
	if (getline <= 0)
		exit(1)

	print "\n<div class=\"mw-highlight\">"
	print "<pre>"

	while ($0 !~ /^```/) {
		print html_ent_format($0)
		if (getline <= 0) {
			print "</pre>"
			print "</div>"
			exit(1)
		}
	}

	print "</pre>"
	print "</div>"
}

# TODO maybe we need to insert some additional attributes into pagename
# for example author name, or something
function wiki_print_pagename(	arr, s)
{
	sub(/^#/, "")
	sub(/^ */, "")
	sub(/ *$/, "")

	# parse out magic words from pagename
	while (match($0, /__[a-zA-Z0-9]+__/, arr)) {
		switch (arr[0]) {
		case "__NOTOC__":
			ctx["print_toc"] = 0
			break
		}
		s = substr($0, 1, RSTART - 1)
		s = s substr($0, RSTART + RLENGTH)
		$0 = s
	}

	$0 = strip_spaces($0)
	if (length($0) > 0)
		print "<h1>" wiki_format_line($0) "</h1>"
}

function wiki_print_mono()
{
	print "<pre>"

	do {
		print wiki_format_line($0)
		if (getline <= 0) {
			print "</pre>"
			exit(1)
		}
	} while (/^ /)

	print "</pre>"
	wiki_format_marks()
}

# For headings and horizontal line
function wiki_print_heading(	n, link)
{
	while (/^#/) {
		sub(/^#/, "")
		n++
	}

	if (n > 6)
		n = 6

	if (ctx["print_toc"]) {
		wiki_print_content()
		ctx["print_toc"] = 0
	}

	link = $0 = strip_spaces($0)
	gsub(/ /, "_", link)
	link = rm_quotes(link)

	print "<h"n" class=\"header\" id=\"" link "\">" wiki_format_line($0) "</h"n">"
}

function wiki_print_hr()
{
	print "<hr>"
}

function wiki_print_list(	n, i, tabcount, list, tag, s)
{
	if (/^\t*\*/) {
		s = $0
		while (s ~ /\*/) {
			n++
			sub(/\*/, "", s)
		}
		# if not supposed to go here then return error
		if (n % 2 == 0)
			return 1
	}

	do {
		if (/^\t*[*+-]/)
			tag = "ul"
		else
			tag = "ol"

		tabcount = 1

		while (/^\t+[*+0-9-]/) {
			sub(/^\t/,"")
			tabcount++
		}

		#close foreign tags in reverse order
		if (tabcount < list["maxlvl"]) {
			for (i = list["maxlvl"]; i > tabcount; i--) {
				#skip unused levels
				if (list[i, "type"] == "")
					continue

				print "</" list[i, "type"] ">"
				list[i, "type"] = ""
			}
		}

		#if tag on same indent din't match, close it
		if (list[tabcount, "type"] && list[tabcount, "type"] != tag) {
			print "</" list[tabcount, "type"] ">"
			list[tabcount, "type"] = ""
		}

		if (list[tabcount, "type"] == "")
			print "<" tag ">"

		sub(/^[*+0-9-]+\.?/, "")
		print "\t<li>" wiki_format_line($0) "</li>"

		list["maxlvl"] = tabcount
		list[tabcount, "type"] = tag

		if (getline <= 0) {
			for (i = list["maxlvl"]; i > 0; i--) {
				#skip unused levels
				if (list[i, "type"] == "")
					continue

				print "</" list[i, "type"] ">"
				list[i, "type"] = ""
			}
			exit(1)
		}

	} while (/^\t*[*+0-9-]/)

	for (i = list["maxlvl"]; i > 0; i--) {
		#skip unused levels
		if (list[i, "type"] == "")
			continue

		print "</" list[i, "type"] ">"
		list[i, "type"] = ""
	}
	wiki_format_marks()
}

function wiki_print_content(	cmd, tmp, file)
{
	print "\
<div id=\"contents\">\n\
<div id=\"contents_title\">\n\
	<h2>" contents "</h2>\n\
</div>\n\
<div id=\"contents-content\">\n\
</div></div>"
}

function wiki_format_line(fmt,		i, j, pref, suf, strong, em, code, wikilink, fun, cont)
{
	strong = em = code = 0
	wikilink = !0
	i = 1

	while (i <= length(fmt)) {
		pref = substr(fmt, 1, i - 1)
		suf = substr(fmt, i)
		tag = ""
		cont = 0

		if (suf ~ /^\*\*/ || suf ~ /^__/) {
			sub(/^\*\*/, "", suf)
			sub(/^__/, "", suf)
			tag = (strong ? "</strong>" : "<strong>")
			strong = !strong
		} else if (suf ~ /^[*_]/) {
			sub(/^[*_]/, "", suf)
			tag = (em ? "</em>" : "<em>")
			em = !em
		} else if (suf ~ /^`/) {
			sub(/^`/, "", suf)
			tag = (code ? "</code>" : "<code>")
			code = !code
		}
		if (tag) {
			fmt = pref tag suf
			i += length(tag)
			continue
		}
		if (match(suf, /^https?:\/\/[^ \t]*\.(jpg|jpeg|gif|png)/)) {
			link = substr(suf, 1, RLENGTH)
			sub(/^https?:\/\/[^ \t]*\.(jpg|jpeg|gif|png)/, "", suf)

			link = "<img src=\"" link "\">"

			i += length(link)
			fmt = pref link suf
			continue
		}
		if (match(suf, /^((https?|ftp|gopher):\/\/|(mailto|news):)[^ \t]*/)) {
			link = substr(suf, 1, RLENGTH)
			sub(/^((https?|ftp|gopher):\/\/|(mailto|news):)[^ \t]*/, "", suf)

			link = "<a href=\"" link "\">" link "</a>"
			# remove mailto: in link description
			sub(/>mailto:/, ">", link)

			i += length(link)
			fmt = pref link suf
			continue
		}
		if (match(suf, /^&[a-z]+;/) || match(suf, /^&#[0-9]+;/)) {
			i += RLENGTH
			continue
		}
		if (suf ~ /^</) {
			sub(/^</, "\\&lt;", suf)
			i += 4
			fmt = pref suf
			continue
		}
		if (suf ~ /^>/) {
			sub(/^>/, "\\&gt;", suf)
			i += 4
			fmt = pref suf
			continue
		}
		if (suf ~ /^&/) {
			sub(/^&/, "&amp;", suf)
			i += length("&amp;")
			fmt = pref suf
			continue
		}
		# Commented out for now
#		if (match(suf, "^" pagename_re)) {
#			if (wikilink) {
#				link = substr(suf, 1, RLENGTH)
#				sub("^" pagename_re, "", suf)
#
#				link = page_ref_format(link)
#
#				i += length(link)
#				fmt = pref link suf
#			} else
#				i += RLENGTH
#
#			continue
#		}

		for (j in line_syntax) {
			if (!match(suf, "^" j))
				continue

			cont = 1

			fun = line_syntax[j]
			res = @fun(substr(suf, RSTART, RLENGTH))
			sub("^" j, "", suf)

			i += length(res)
			fmt = pref res suf
			break
		}

		if (cont == 0)
			i += 1
	}

	if (strong)
		fmt = fmt "</strong>"
	if (em)
		fmt = fmt "</em>"
	if (code)
		fmt = fmt "</code>"

	return fmt
}

function page_ref_format(link)
{
	if (pages[link])
		return "<a href=\""(rewrite == "true" ? "" : scriptname)"/"link"\">"link"</a>"
	else
		return link"<a href=\""(rewrite == "true" ? "" : scriptname)"/"link"\">?</a>"
}

# HTML entities for <, > and &
function html_ent_format(fmt,	sa, tmp)
{
	#skip already escaped stuff
	split(fmt, sa, "")
	for (i = 1; i <= length(sa); i++) {
		if (sa[i] != "&")
			continue

		tmp = substr(fmt, i)

		if (match(tmp, /^&[a-z]+;/))
			continue
		if (match(tmp, /^&#[0-9]+;/))
			continue
		sa[i] = "&amp;"
	}

	tmp = ""
	for (i = 1; i <= length(sa); i++) {
		tmp = tmp sa[i]
	}
	fmt = tmp
	
	gsub(/</, "\\&lt;", fmt)
	gsub(/>/, "\\&gt;", fmt)

	return fmt
}

function wiki_format_url(fmt,	img, i, pref, ref, suf, n, name, link, ret, atag)
{
	if (fmt ~ /^!/) {
		img = 1
		sub(/^!/, "", fmt)
	}

	sub(/^!/, "", fmt)
	name = gensub("^\\[([^\\[\\]]+)\\]\\(([^()]+)\\)", "\\1", "1", fmt)
	link = gensub("^\\[([^\\[\\]]+)\\]\\(([^()]+)\\)", "\\2", "1", fmt)

	if (link ~ "^" pagename_re "$") {
		if (pages[link])
			return "<a href=\""(rewrite == "true" ? "" : scriptname)"/"link"\">"name"</a>"
		else
			return name"<a href=\""(rewrite == "true" ? "" : scriptname)"/"link"\">?</a>"
	}

	if (link !~ /^((https?|ftp|gopher|file):\/\/|(mailto|news):)/)
		link = "http://" link

	if (!img)
		return gen_href(link, name)

	if (link ~ /^([^ ]+ +)=([0-9]*)x([0-9]*)/) {
		width  = gensub(/^([^ ]+ +)=([0-9]*)x([0-9]*)/, "\\2", "1", link)
		height = gensub(/^([^ ]+ +)=([0-9]*)x([0-9]*)/, "\\3", "1", link)
		if (width)
			img_options["width"] = width
		if (height)
			img_options["height"] = height
		sub("=.*$", "", link)
	}

	ret = shape_link_image(link)

	delete img_options

	if (ret != "")
		return ret
	else
		return gen_href(link, name)
}

function shape_link_image(link,		options)
{
	if (link !~ /https?:\/\/[^\t]*\.(jpg|jpeg|gif|png)/)
		return ""

	options = ""
	for (item in img_options)
		options = options sprintf("%s=\"%s\" ", item, img_options[item])

	link = sprintf("<img %ssrc=\"%s\">", options, link)
	return link
}

function gen_href(link, text)
{
	s = sprintf("<a href=\"%s\">%s</a>",
	    html_escape(link),
	    html_escape(text))
	return s
}

function html_escape(s) {
	gsub(/"/, "\\&quot;", s)
	gsub(/&/, "\\\\&", s)
	gsub(/\[/, "\\&#91;", s)
	gsub(/\]/, "\\&#93;", s)

	gsub(/\\/, "\\\\", s)
	gsub(/&/, "\\\\&", s)

	return s
}

