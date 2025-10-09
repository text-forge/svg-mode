extends TextForgeMode

const SELF_CLOSING_TAGS := []

var keyword_colors: Dictionary[Color, Array] = {
	U.get_syntax_color(U.SyntaxColors.KEYWORD_1): ["svg", "g", "defs", "use", "symbol", "view"],
	U.get_syntax_color(U.SyntaxColors.KEYWORD_2): ["rect", "circle", "ellipse", "line", "polyline", "polygon", "path"],
	U.get_syntax_color(U.SyntaxColors.KEYWORD_3): ["text", "tspan", "textPath", "linearGradient", "radialGradient", "stop", "pattern", "style", "font", "font-face", "glyph", "missing-glyph"],
	U.get_syntax_color(U.SyntaxColors.BUILTIN): ["filter", "feBlend", "feColorMatrix", "feComponentTransfer", "feComposite", "feConvolveMatrix", "feDiffuseLighting", "feDisplacementMap", "feFlood", "feGaussianBlur", "feImage", "feMerge", "feMorphology", "feOffset", "feSpecularLighting", "feTile", "feTurbulence", "animate", "animateTransform", "set"],
	U.get_syntax_color(U.SyntaxColors.CUSTOM_2): ["a", "script", "desc", "title", "metadata"],
	U.get_syntax_color(U.SyntaxColors.CUSTOM_5): ["clipPath", "mask"],
	U.get_syntax_color(U.SyntaxColors.MEMBER): [
		"xmlns", "width", "height", "viewBox", "preserveAspectRatio", "id", "class", "style", 
		"transform", "x", "y", "cx", "cy", "r", "rx", "ry", "x1", "y1", "x2", "y2", "points", "d",
		"fill", "stroke", "stroke-width", "opacity", "fill-opacity", "stroke-opacity", "stroke-linecap",
		"stroke-linejoin", "stroke-dasharray", "stroke-dashoffset", "font-size", "font-family", 
		"font-weight", "text-anchor", "letter-spacing", "word-spacing", "dominant-baseline", 
		"alignment-baseline", "lengthAdjust", "gradientUnits", "gradientTransform", "xlink:href", 
		"offset", "stop-color", "stop-opacity", "patternUnits", "patternContentUnits", "patternTransform",
		"filter", "clip-path", "mask", "stdDeviation", "in", "result", "type", "values", "kernelMatrix",
		"order", "radius", "surfaceScale", "specularConstant", "specularExponent", "attributeName", 
		"from", "to", "by", "dur", "begin", "end", "repeatCount", "fill", "keyTimes", "keySplines", 
		"calcMode", "additive", "accumulate", "href", "target", "role", "aria-label", "tabindex", 
		"focusable", "cursor", "unicode", "horiz-adv-x", "units-per-em", "ascent", "descent", 
		"glyph-name", "lang"
	]
}

func _initialize_mode() -> Error:
	_initialize_highlighter()
	comment_delimiters.append({
		"start_key": "<!--",
		"end_key": "-->",
		"line_only": false,
	})
	string_delimiters.append({
		"start_key": '"',
		"end_key": '"',
		"line_only": false,
	})
	string_delimiters.append({
		"start_key": "'",
		"end_key": "'",
		"line_only": false,
	})
	
	_enable_auto_format_feature()
	
	return OK


func _auto_format(text: String) -> String:
	var indent_level := 0
	var indent_str := " ".repeat(Global.get_editor().indent_size) if Global.get_editor().indent_use_spaces else "\t"
	var formatted := []

	var raw_lines := text.split("\n", false)
	var lines := _merge_multiline_tags(raw_lines)

	for line in lines:
		var chunks := _split_tags(line)
		for chunk in chunks:
			if chunk == "":
				continue
			chunk = _clean_attribute_spacing(chunk)
			var tag_delta := _count_tag_diff(chunk)
			if tag_delta < 0:
				indent_level = max(0, indent_level + tag_delta)
			formatted.append(indent_str.repeat(indent_level) + chunk)
			if tag_delta > 0:
				indent_level += tag_delta

	return "\n".join(formatted)


func _update_code_completion_options(text: String) -> void:
	for color in keyword_colors:
		for keyword in keyword_colors[color]:
			if keyword in SELF_CLOSING_TAGS:
				Global.get_editor().add_code_completion_option(CodeEdit.KIND_CLASS, "<" + keyword + "/>", keyword + "/>", color)
			else:
				Global.get_editor().add_code_completion_option(CodeEdit.KIND_CLASS, "<" + keyword + ">", keyword + ">\n\t\n</" + keyword + ">", color)


func _generate_outline(text: String) -> Array:
	var parser = XMLParser.new()
	parser.open_buffer(text.to_utf8_buffer())

	var outline := []
	var stack := []

	while parser.read() != ERR_FILE_EOF:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var node_name = parser.get_node_name()
				var line = parser.get_current_line()
				var node := [node_name, line]

				if stack.size() > 0:
					stack[-1].append(node)
				else:
					outline.append(node)

				if not parser.is_empty() and not SELF_CLOSING_TAGS.has(node_name):
					stack.append(node)

			XMLParser.NODE_ELEMENT_END:
				if stack.size() > 0:
					stack.pop_back()

	return outline


func _generate_preview(text: String) -> Variant:
	var image := Image.new()
	var err := image.load_svg_from_string(text)
	if err or not image:
		return "Failed to generate SVG from code, error code {0}.".format([err])
	var texture := ImageTexture.create_from_image(image)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


# TODO
func _lint_file(text: String) -> Array[Dictionary]:
	return Array([], TYPE_DICTIONARY, "", null)


func _initialize_highlighter() -> void:
	syntax_highlighter = CodeHighlighter.new()
	syntax_highlighter.number_color = U.get_syntax_color(U.SyntaxColors.NUMBER)
	syntax_highlighter.symbol_color = U.get_syntax_color(U.SyntaxColors.SYMBOL)
	syntax_highlighter.function_color = U.get_syntax_color(U.SyntaxColors.DEFAULT)
	syntax_highlighter.member_variable_color = U.get_syntax_color(U.SyntaxColors.MEMBER)
	for color in keyword_colors:
		for keyword in keyword_colors[color]:
			syntax_highlighter.add_keyword_color(keyword, color)
	syntax_highlighter.add_color_region('"', '"', U.get_syntax_color(U.SyntaxColors.STRING), false)
	syntax_highlighter.add_color_region("'", "'", U.get_syntax_color(U.SyntaxColors.STRING), false)
	syntax_highlighter.add_color_region('<!--', '-->', U.get_syntax_color(U.SyntaxColors.COMMENT), false)


func _split_tags(line: String) -> PackedStringArray:
	var result := []
	var regex := RegEx.new()
	regex.compile(r"(<[^>]+>)")
	var pos := 0
	for match in regex.search_all(line):
		if match.get_start() > pos:
			result.append(line.substr(pos, match.get_start() - pos).strip_edges())
		result.append(match.get_string().strip_edges())
		pos = match.get_end()
	if pos < line.length():
		result.append(line.substr(pos).strip_edges())
	return result


func _clean_attribute_spacing(line: String) -> String:
	var cleaned := line
	var regex := RegEx.new()
	regex.compile(r'\s*=\s*')
	cleaned = regex.sub(cleaned, '=', true)
	regex.compile(r'\s{2,}')
	cleaned = regex.sub(cleaned, ' ', true)
	return cleaned.strip_edges()


func _merge_multiline_tags(lines: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	var buffer := ""
	var in_open_tag := false

	for line in lines:
		if not in_open_tag:
			buffer = line
			if line.count("<") > line.count(">") and not line.strip_edges().ends_with(">"):
				in_open_tag = true
			else:
				result.append(line)
		else:
			buffer += " " + line
			if ">" in line:
				result.append(buffer)
				buffer = ""
				in_open_tag = false

	if in_open_tag and buffer != "":
		result.append(buffer)

	return result


func _count_tag_diff(line: String) -> int:
	var diff := 0
	var regex := RegEx.new()
	regex.compile("<(/?)(\\w+)[^>]*?>")
	var matches := regex.search_all(line)
	for match in matches:
		var closing := match.get_string(1) == "/"
		var tag := match.get_string(2).to_lower()
		var self_closing := tag in SELF_CLOSING_TAGS or match.get_string(0).ends_with("/>")
		if self_closing:
			continue
		elif closing:
			diff -= 1
		else:
			diff += 1
	return diff