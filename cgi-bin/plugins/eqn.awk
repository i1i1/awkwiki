BEGIN {
	syntaxlang["eq"] = "eqn_fmt"
	line_syntax["\\$\\$[^\\$]+\\$\\$"] = "eqn_fmt_inline"
}

function eqn_gen_image(eqn,	cmd, image, alt, align_property)
{
	alt = eqn
	sub(/^[ \t]*/, "", s); sub(/[ \t]*$/, "", s)

	cmd = "nohup ./eqn_render.sh "esc_sh(eqn)
	cmd | getline image
	cmd | getline align_property
	close(cmd)
	#printf("awk offset is %s image is '%s'\n", align_property, image)
	if (align_property == "")
		align_property = "0"

	img = sprintf("<img alt=\"%s\" src=\"%s\" " \
		      "style=\"vertical-align:%spx\">",
		      html_escape(alt), image, align_property)
	return img
}

function eqn_fmt()
{
	tmp = ""

	if (getline <= 0)
		exit(1)

	while ($0 !~ /^```/) {
		tmp = tmp "\n" $0
		if (getline <= 0)
			exit(1)
	}

	tmp = substr(tmp, 2)

	if (blankline) {
		blankline = 0
		print "<p>"
	}

	print eqn_gen_image(tmp)
}

function eqn_fmt_inline(str)
{
	sub(/^\$\$/, "", str)
	sub(/\$\$$/, "", str)

	return eqn_gen_image(str)
}

