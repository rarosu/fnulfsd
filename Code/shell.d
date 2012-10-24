module shell;

import std.stdio;
import std.conv;
import std.string;
import fs = filesystem;


fs.Address curdir = 0;

int function(string[])[string] programs;

string[] split(string arg, char delimiter = ' ')
{
    string[] result;

    int prev = 0;
    int curr = 0;

    foreach (char c; arg)
    {
        if (c == delimiter)
        {
            result ~= strip(arg[prev .. curr]);
            prev = curr;
        }

        curr++;
    }

    result ~= strip(arg[prev .. $]);

    return result;
}

void shell() {
    programs["format"] = &format;
    programs["quit"] = &quit;
    programs["save"] = &save;
    programs["read"] = &read;
    programs["memdmp"] = &memdmp;
    programs["create"] = &create;
    programs["cat"] = &cat;
    programs["ls"] = &ls;
    programs["mkdir"] = &mkdir;


    string input;
    do {
        writef("> ");
        stdin.readln(input);
        input = input[0 .. $ - 1];

        if (input == "")
            continue;

        string[] args = split(input);
        writeln(args);

        int i = 0;
        for (; i < programs.length; ++i) {
            if (programs.keys[i] == args[0])
                break;
        }

        if (i == programs.length) {
            writefln("No such program: %s", args[0]);
        } else {
            int return_code = programs[args[0]](args[1 .. $]);
            if (return_code != 0) {
                writefln("%s returned with code %d", args[0], return_code);
            }
        }

    } while (input != "quit");
}


int format(string[] args) {
    fs.format();
    writefln("Formatted new filesystem");
    return 0;
}

int quit(string[] args) {
    writefln("Good bye");
    return 0;
}

int save(string[] args) {
    if (args.length != 1)
        return 1;

    fs.save_fs(args[0]);
    writefln("Saving filesystem to %s", args[0]);
    return 0;
}

int read(string[] args) {
    if (args.length != 1)
        return 1;

    fs.load_fs(args[0]);
    writefln("Loaded filesystem from %s", args[0]);
    return 0;
}

int memdmp(string[] args) {
    writefln("dumping...");
    fs.memdmp("memdmp.txt");
    writefln("memdmp complete");
    return 0;
}

int create(string[] args) {
    if (args.length != 1)
        return 1;

    string filename = args[0];
    //fs.Address parent = to!ubyte(args[1]);

    string contents;
    writef("Enter file contents: ");
    stdin.readln(contents);
    contents = contents[0 .. $ - 1];

    fs.Address file = fs.create_file(filename, curdir);

    writefln("Creating file at address %d", file);

    fs.append(file, cast(byte[])contents);

    return 0;
}

int cat(string[] args) {
    if (args.length < 1)
        return 1;

    fs.Address file = fs.find_file_by_name(args[0], curdir);
    if (file != fs.E_FILE_NOT_FOUND)
        return 1;

    writefln("Found file at address %d", file);

    byte[] data = fs.read_from_file(file);

    writefln(cast(string)data);

    return 0;
}

int ls(string[] args) {
    byte[] files = fs.read_from_file(curdir);
    for (int i = 0; i < files.length; ++i) {
        fs.BlockHeader* bh = fs.get_block_ptr(files[i]);
        fs.FileHeader* fh = fs.get_file_ptr(files[i]);

        string filename = cast(string)fh.name;
        if ((bh.flags & fs.FLAG_DIRECTORY) != 0)
            filename ~= "/";
        writefln(fh.name);
    }

    return 0;
}

int mkdir(string[] args) {
    if (args.length < 1)
        return 1;

    string name = args[0];

    writefln("Making new directory: %s", args[0]);
    if (fs.create_directory(name, curdir) != fs.E_BLOCK_NOT_FOUND)
        return 0;
    else
        return 1;
}
