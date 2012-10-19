import std.stdio;
import std.string;
import std.file;
//import std.stream;
import std.c.string;

/+ STRUCTS & TYPEDEFS +/
alias ubyte Address;

struct FileHeader {
    char name[32];
    ubyte block_count;
    ubyte flags;
}

struct BlockHeader {
    Address next_block;
    Address previous_block;
    ushort byte_count;
}

struct DirectoryHeader {
    Address parent_block;
    ubyte file_count;
}

/+ CONSTANTS +/
const ubyte ALLOCATED_FLAG = 0b00000001;
const ubyte DIRECTORY_FLAG = 0b00000010;

const uint BLOCK_COUNT = 250;
const uint BLOCK_SIZE = 512;

/+ GLOBAL VARIABLES +/
byte fs_data[BLOCK_COUNT][BLOCK_SIZE];


int main(char[][] argv) {
    display_shell_prompt();

    return 0;
}

void display_shell_prompt() {
    string input;
    while (input != "quit") {
        // prompt user for input
        writef("> ");
        stdin.readln(input);

        // strip newline from input
        input = input[0 .. $ - 1];

        // parse input
        switch (input) {
            case "format":
                format_fs();
            break;

            case "memdmp":
                memdmp("memdmp.txt");
            break;

            case "test":
                string name = "Hello world";
                FileHeader* fh = cast(FileHeader*)fs_data[0];

                fh.name = name[0 .. 32];
            break;

            default:
            break;
        }
    }
}

void memdmp(string file) {
    File dmpfile = File(file, "w");

    for (int i = 0; i < BLOCK_COUNT; ++i) {
        dmpfile.writefln("Block %d", i);
        dmpfile.write(fs_data[i]);
        dmpfile.writeln();
    }
}

bool create_directory(string name, Address destination, Address parent) {
    writefln("Creating directory: %s", name);

    FileHeader* fh = cast(FileHeader*)fs_data[destination];



    // do not overwrite allocated memory
    if ((fh.flags & ALLOCATED_FLAG) != 0)
        return false;

    // setup initial metadata
    if (name.length <= 32)
        fh.name[0..name.length] = name;
    else
        fh.name = name[0..32];
    fh.block_count = 1;
    fh.flags = ALLOCATED_FLAG | DIRECTORY_FLAG;

    BlockHeader* bh = (cast(BlockHeader*)fh) + FileHeader.sizeof;
    bh.next_block = destination;
    bh.previous_block = destination;
    bh.byte_count = DirectoryHeader.sizeof;

    DirectoryHeader* dh = (cast(DirectoryHeader*)bh) + BlockHeader.sizeof;
    dh.parent_block = parent;
    dh.file_count = 0;

    return true;
}

void format_fs() {
    // clear all blocks in the fs
    memset(fs_data.ptr, 0, byte.sizeof * BLOCK_COUNT * BLOCK_SIZE);

    // create the root directory as only file
    if (!create_directory("root", 0, 0))
        writefln("Failed to create root directory");
}
