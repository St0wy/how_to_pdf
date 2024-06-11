#import "Basic";
#import "File";
#import "File_Utilities";
#import "String";
#import "Process";

#if OS == .WINDOWS {
	DEFAULT_HOW_TO_PATH :: "C:\\jai\\how_to"; // IDK what to set on linux since its probably in home dir
} else {
	DEFAULT_HOW_TO_PATH :: "";
}

Chapter :: struct
{
	full_path: string;
	name: string;
	is_directory: bool;
}

typst_document_builder: String_Builder;

main :: ()
{
	push_allocator(temp);

	args := get_command_line_arguments();

	path := ifx args.count > 1 then args[1];
	if path.count == 0 then path = DEFAULT_HOW_TO_PATH;

	absolute_path, success := get_absolute_path(path);
	assert(success, "Could not get absolute path");

	t0 := seconds_since_init();
	
	chapters := get_chapter_list(absolute_path);

	init_string_builder(*typst_document_builder);
	append(*typst_document_builder, TYPST_PREAMBLE);
	
	for chapters
	{
		translate_chapter_title(it);

		if it.is_directory 
		{
			translate_folder(it.full_path);
		}
		else
		{
			translate_file(it.full_path);
		}
	}

	success_write := write_entire_file("how_to.typ", *typst_document_builder);
	assert(success_write, "Could not write document");

	print("Generated typst file in % seconds\n", seconds_since_init() - t0);
	write_string("Compiling typst document...\n");
	t0 = seconds_since_init();

	command := break_command_into_strings("typst c --font-path fonts how_to.typ");
	result, out, error := run_command(..command);
	write_string(out);
	
	if result.exit_code != 0
	{
		write_string("Failed to build typst document:\n");
		write_string(error);
		return;
	}

	print("Compiled typst document successfully in % seconds\n", seconds_since_init() - t0);

	file_delete("how_to.typ");
}

translate_file :: (path: string)
{
	code, success := read_entire_file(path);
	assert(success, tprint("Could not read file %\n", path));
	print_to_builder(*typst_document_builder, "== `%`\n", path);
	append(*typst_document_builder, "```jai\n");
	append(*typst_document_builder, code);
	append(*typst_document_builder, "```\n\n");
}

translate_folder :: (path: string)
{
	sub_files := file_list(path, true);

	// Double loop is kinda ugly, sorry
	// We want first.jai or main.jai to appear first
	files: [..] string;
	for sub_files if ends_with(it, "first.jai") || ends_with(it, "main.jai") array_add(*files, it);
	for sub_files if (ends_with(it, ".jai") && !ends_with(it, "first.jai") && !ends_with(it, "main.jai")) array_add(*files, it);

	for files translate_file(it);
}

translate_chapter_title :: (chapter: Chapter)
{
	name_no_extension := chapter.name;
	if !chapter.is_directory then name_no_extension.count -= 4;
	
	splitted := split(name_no_extension, "_");
	name_builder: String_Builder;
	init_string_builder(*name_builder);
	append(*name_builder, "= ");
	
	for i: 1..splitted.count - 1
	{
		splitted[i][0] = capitalize(splitted[i][0]);
		append(*name_builder, splitted[i]);
		append(*name_builder, " ");
	}
	
	append(*name_builder, "\n\n");
	append(*typst_document_builder, builder_to_string(*name_builder));
}

capitalize :: (char: u8) -> u8
{
	if char >= #char "A" && char <= #char "Z" then return char;

	return char - cast(u8) (#char "a" - #char "A");
}

is_number :: (char: u8) -> bool
{
	return char >= #char "0" && char <= #char "9";
}

get_chapter_list :: (path: string, follow_directory_symlinks := true) -> [] Chapter #must
{
	chapters : [..] Chapter;

	visitor :: (info: *File_Visit_Info, user_data: *[..] Chapter) {
		is_chapter := info.short_name.count > 3 && is_number(info.short_name[0]) && is_number(info.short_name[1]) && is_number(info.short_name[2]);
		is_jai_file := false;
		if !info.is_directory
		{
			name := info.short_name;
			name.data += name.count - 3;
			name.count = 3;;
			if name == "jai" then is_jai_file = true;
		}

		is_dir_or_jai_file := info.is_directory || is_jai_file;
		if is_chapter && is_dir_or_jai_file
		{
			array_add(user_data, .{copy_string(info.full_name), copy_string(info.short_name), info.is_directory});
		}
	}

	visit_files(path, false, *chapters, visitor, follow_directory_symlinks=follow_directory_symlinks, visit_directories=true);

	return chapters;
}

TYPST_PREAMBLE :: #string DONE
#import "@preview/ilm:1.1.1": *
#import "@preview/codly:0.2.0": *

#show: ilm.with(
  title: [Jai How-Tos],
  author: "Generated with how_to_pdf",
  date: datetime(year: 2024, month: 06, day: 11), // Maybe date should be when the script is started
  figure-index: (enabled: false),
  table-index: (enabled: false),
  listing-index: (enabled: false),
  chapter-pagebreak: false
)

#set page("a4", margin: 1.5cm)
#set raw(syntaxes: "Jai.sublime-synt", tab-size: 4)
#show raw: set text(font: "Monaspace Neon")
#show: codly-init.with()
#codly(
  enable-numbers: true,
  zebra-color: white,
)


DONE