#TODO: escape paths

# escape shell
function esc_sh(s,		arr, n, i, ret)
{
	n = split(s, arr, "");
	ret = ""
	for (i = 1; i <= n; i++) {
		switch (arr[i]) {
		case "\\":
			arr[i] = "\\\\"
			break
		case "$":
			arr[i] = "\\$"
			break
		case "\"":
			arr[i] = "\\\""
			break
		}
		ret = ret arr[i]
	}
	return "\""ret"\""
}

function arr_get_idx(arr, val,		tmp)
{
	for (tmp in arr) {
		if (val == arr[tmp])
			return tmp
	}
	return 0;
}

function arrlen(a,	i, x) {
	for (x in a)
		i++

	return i
}

function mktemp(dstdir,	dirname)
{
	cmd = "mktemp " dstdir "XXXXXXXXX"
	cmd | getline dirname
	close(cmd)

	return dirname
}

function rmfile(fpath,		unused)
{
	cmd = "rm -f '" fpath "'"
	cmd | getline unused
	close(cmd)
}

function strip_spaces(s)
{
	gsub(/^[ \t]+/, "", s)
	gsub(/[ \t]+$/, "", s)
	gsub(/[ \t]+/, " ", s)
	return s
}

function rm_quotes(s)
{
	gsub(/''''''/, "", s)
	gsub(/'''/, "", s)
	gsub(/''/, "", s)
	gsub(/``/, "", s)
	return s
}

