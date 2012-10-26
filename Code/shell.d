module shell;

import std.stdio;
import std.conv;
import std.string;
import fs = filesystem;


fs.Address curdir = 0;                              // The working directory

int function(string[])[string] programs;            // The runnable commands

string[] split(string arg, char delimiter = ' ')
{
    string[] result;

    int prev = 0;
    int curr = 0;

    foreach (char c; arg)
    {
        if (c == delimiter)
        {
            result ~= chompPrefix(arg[prev .. curr], "" ~ delimiter);   //removes the delimiter
            prev = curr;
        }

        curr++;
    }

    result ~= chompPrefix(arg[prev .. $], "" ~ delimiter);              //removes the delimiter.

    return result;
}

void shell() {
    writefln("Hello");
    writefln("FnulShell 1.0");
    writefln("Type 'help' for a list of commands");
    writeln();

    programs["clear"] = &clear;
    programs["help"] = &help;
    programs["format"] = &format;
    programs["quit"] = &quit;
    programs["save"] = &save;
    programs["read"] = &read;
    programs["memdmp"] = &memdmp;
    programs["create"] = &create;
    programs["cat"] = &cat;
    programs["ls"] = &ls;
    programs["mkdir"] = &mkdir;
    programs["copy"] = &copy;
    programs["append"] = &append;
    programs["rename"] = &rename;
    programs["cd"] = &cd;
    programs["pwd"] = &pwd;
    programs["rm"] = &rm;

    try {
        read(["test.bin"]);                                                 // test.bin is a system especially prepared for the course examination
    }
    catch {
        writeln("Could not find an existing filesystem, formatting...");
        format([""]);
    }
    string input;
    do {
        writef("$ ");
        stdin.readln(input);
        input = input[0 .. $ - 1];

        if (input == "")
            continue;

        string[] args = split(input);

        int i = 0;
        for (; i < programs.length; ++i) {                                  // search linearly through the array of commands
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


// Make sure a filename is valid
bool is_filename_valid(string filename) {
    foreach (char c; filename) {
        if (c == '/')   return false;
    }

    return true;
}

// Clear the screen
int clear(string[] args) {
    for (int i = 0; i < 100; ++i)
        writeln();

    return 0;
}


// Lists available commands
int help(string[] args) {
    foreach (string name; programs.keys) {
        write(name ~ " ");
    }

    writeln();

    return 0;
}


int format(string[] args) {
    fs.format();
    writefln("Formatted new filesystem.");
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
    writefln("Saving filesystem to %s...", args[0]);
    return 0;
}


int read(string[] args) {
    if (args.length != 1)
        return 1;

    if (!fs.load_fs(args[0]))
        return 1;
    curdir = 0;

    writefln("Loaded filesystem from %s.", args[0]);
    return 0;
}


// Dumps system state into a plaintext file, for debugging
int memdmp(string[] args) {
    writefln("dumping...");
    fs.memdmp("memdmp.txt");
    fs.memdmp2("memdmp2.txt");
    writefln("memdmp complete");
    return 0;
}


int create(string[] args) {
    if (args.length != 1)
        return 1;

    string[] path = split(args[0], '/');
    string filename = path[$ - 1];          // remove trailing newline

    fs.Address dir;
    if (path.length == 1)                   // Checks if a path was specified
        dir = curdir;
    else
        dir = fs.find_file_from_path(path[0 .. $ - 1], curdir);

    // make sure the inserted path is valid
    if (dir >= fs.BLOCK_COUNT)
        return 1;

    // make sure a file with the same name doesn't already exist
    if (fs.find_file_from_path(path, curdir) < fs.BLOCK_COUNT)
        return 1;

    // let the user enter file content
    string contents;
    writef("Enter file contents: ");
    stdin.readln(contents);
    contents = contents[0 .. $ - 1];        // remove trailing newline

    // create the file and append the initial data
    fs.Address file = fs.create_file(filename, dir);
    if (file > fs.BLOCK_COUNT)
        return 1;

    fs.append(file, cast(byte[])contents);

    return 0;
}


// Catenates the contents of all files passed as arguments to the output stream.
int cat(string[] args) {
    string output;

    foreach (string arg; args) {
        fs.Address file = fs.find_file_from_path(split(args[0], '/'), curdir);
        if (file >= fs.BLOCK_COUNT)
            return 1;

        byte[] data = fs.read_from_file(file);
        output ~= cast(string)data;
    }
    writefln(output);

    return 0;
}


int ls(string[] args) {
    writeln(".");
    if (curdir != 0)
        writeln("..");

    byte[] files = fs.read_from_file(curdir);
    for (int i = 0; i < files.length; ++i) {
        fs.BlockHeader* bh = fs.get_block_ptr(files[i]);
        fs.FileHeader* fh = fs.get_file_ptr(files[i]);

        string filename = fs.extract_filename(fh.name);
        if ((bh.flags & fs.FLAG_DIRECTORY) != 0)
            filename ~= "/";
        writefln(filename);
    }

    return 0;
}


int mkdir(string[] args) {
    if (args.length < 1)
        return 1;

    string[] path = split(args[0], '/');
    string name = path[$ - 1];

    fs.Address dir;
    if (path.length == 1)                       // Checks if a path was specified
        dir = curdir;
    else
        dir = fs.find_file_from_path(path[0 .. $ - 1], curdir);

    // make sure the path is valid
    if (dir >= fs.BLOCK_COUNT)
        return 1;

    // make sure a file with the same name doesn't already exist
    if (fs.find_file_from_path(path, curdir) < fs.BLOCK_COUNT)
        return 1;

    // create the directory
    if (fs.create_directory(name, dir) >= fs.BLOCK_COUNT)
        return 0;

    writefln("Made new directory: %s", args[0]);
    return 0;
}


int copy(string[] args) {
    if (args.length < 2)
        return 1;

    string[] source_path = split(args[0], '/');
    string[] target_path = split(args[1], '/');

    string source_name = source_path[$ - 1];
    string target_name = target_path[$ - 1];

    fs.Address target_dir = 0;
    fs.Address target_file = 0;
    fs.Address source_file = 0;

    // find target directory
    if (target_path.length == 1)            // Checks if a path was specified
        target_dir = curdir;
    else
        target_dir = fs.find_file_from_path(target_path[0 .. $ - 1], curdir);

    // make sure the target directory is valid
    if (target_dir >= fs.BLOCK_COUNT)
        return 1;

    // make sure a file with the same name doesn't exist already
    if (fs.find_file_from_path(target_path, curdir) < fs.BLOCK_COUNT)
        return 1;

    // find source file
    source_file = fs.find_file_from_path(source_path, curdir);
    if (source_file >= fs.BLOCK_COUNT)
        return 1;

    // copy
    target_file = fs.copy(source_file, target_dir, target_name);
    if (target_file >= fs.BLOCK_COUNT)
        return 1;

    writefln("Copied %s to %s", args[0], args[1]);

    return 0;
}



int append(string[] args){
    if (args.length != 1)
        return 1;

    string[] path = split(args[0], '/');
    string filename = path[$ - 1];

    string contents;
    writef("Enter append contents: ");
    stdin.readln(contents);
    contents = contents[0 .. $ - 1];


    fs.Address dir;
    if (path.length == 1)
        dir = curdir;
    else
        dir = fs.find_file_from_path(path[0 .. $ - 1], curdir);

    if (dir >= fs.BLOCK_COUNT)
        return 1;

    fs.append(fs.find_file_by_name(filename, dir), cast(byte[])contents);

    return 0;
}

int rename(string[] args) {
    if (args.length != 2)
        return 1;

    string[] path = split(args[0], '/');

    string old_filename = path[$ - 1];
    string new_filename = args[1];

    if (!is_filename_valid(new_filename))
        return 1;

    fs.Address dir;
    if (path.length == 1)
        dir = curdir;
    else
        dir = fs.find_file_from_path(path[0 .. $ - 1], curdir);

    if (dir >= fs.BLOCK_COUNT)
        return 1;

    fs.Address file = fs.find_file_by_name(old_filename, dir);
    if (file >= fs.BLOCK_COUNT)
        return 1;

    fs.rename(file, new_filename);

    writefln("Renamed file %s to %s", args[0], new_filename);

    return 0;
}

int cd(string[] args){
    if (args.length != 1)
        return 1;

    // ignore, traverse to current directory
    if (args[0] == ".")
        return 0;

    // traverse to parent directory
    if (args[0] == ".."){
        fs.FileHeader* fh = fs.get_file_ptr(curdir);
        curdir = fh.parent_block;
        pwd(args[0 .. 0]);
        return 0;
    }

    // find the directory
    string[] path = split(args[0], '/');

    fs.Address newdir = fs.find_file_from_path(path, curdir);
    if (newdir == fs.E_NOT_A_DIRECTORY)
        return 1;

    curdir = newdir;
    pwd(args[0 .. 0]);

    return 0;
}

int pwd(string[] args) {
    if (args.length > 0)
        return 1;

    write("/");
    string[] path = fs.extract_path(curdir);
    foreach (string dir; path){
        write(dir ~ "/");
    }

    writeln();

    return 0;
}

int rm(string[] args) {
    if (args.length != 1)
        return 1;

    fs.Address file = fs.find_file_from_path(split(args[0], '/'), curdir);
    if (file >= fs.BLOCK_COUNT)
        return 1;

    fs.delete_file(file);

    writefln("File %s deleted.", args[0]);

    return 0;
}
