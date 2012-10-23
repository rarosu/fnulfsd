module filesystem;

import std.stdio;
import std.c.string;


/+ STRUCTS & TYPEDEFS +/
alias ubyte Address;


struct BlockHeader {
    Address next_block;
    Address previous_block;
    ubyte flags;
    ushort byte_count;
}

struct FileHeader {
    char name[32];
    Address parent_block;
}

struct DirectoryHeader {
    ubyte file_count;
}

/+ CONSTANTS +/
const ubyte FLAG_ALLOCATED = 0b00000001;
const ubyte FLAG_DIRECTORY = 0b00000010;

const Address E_BLOCK_NOT_FOUND = 255;

const uint BLOCK_COUNT = 250;
const uint BLOCK_SIZE = 512;

/+ GLOBAL VARIABLES +/
byte fs_data[BLOCK_COUNT][BLOCK_SIZE];


/+ FUNCTIONS +/
BlockHeader* get_block_ptr(Address a) {
    return cast(BlockHeader*)fs_data[a].ptr;
}

FileHeader* get_file_ptr(Address a) {
    return cast(FileHeader*) (get_block_ptr(a) + BlockHeader.sizeof);
}

DirectoryHeader* get_directory_ptr(Address a) {
    return cast(DirectoryHeader*) (get_file_ptr(a) + FileHeader.sizeof);
}

Address find_free_block() {
    for (Address i = 0; i < fs_data.length; ++i) {
        BlockHeader* bh = cast(BlockHeader*)fs_data[i].ptr;
        if ((bh.flags & FLAG_ALLOCATED) == 0)
            return i;
    }

    return E_BLOCK_NOT_FOUND;
}

/// fill up a block header and link it with other blocks
void create_block(Address a, Address previous, Address next) {
    BlockHeader* bh = get_block_ptr(a);
    BlockHeader* bh_prev = get_block_ptr(previous);
    BlockHeader* bh_next = get_block_ptr(next);

    bh.next_block = next;
    bh.previous_block = previous;
    bh.flags = FLAG_ALLOCATED;
    bh.byte_count = 0;

    bh_prev.next_block = a;
    bh_next.previous_block = a;
}

/// create a new block and link it to an existing file
Address create_block(Address previous, Address next) {
    Address a = find_free_block();
    if (a != E_BLOCK_NOT_FOUND) {
        create_block(a, previous, next);
    }

    return a;
}

/// create a standalone block for new files
Address create_block() {
    Address a = find_free_block();
    if (a != E_BLOCK_NOT_FOUND) {
        create_block(a, a, a);
    }

    return a;
}

/// allocate a new block and create an empty file
Address create_file(string name, Address parent) {
    Address a = create_block();
    BlockHeader* bh = get_block_ptr(a);
    FileHeader* fh = get_file_ptr(a);

    // initialize metadata
    if (name.length <= 32)
        fh.name[0..name.length] = name;
    else
        fh.name = name[0..32];
    fh.parent_block = parent;

    return a;
}

Address create_directory(string name, Address parent) {
    Address a = create_file(name, parent);
    BlockHeader* bh = get_block_ptr(a);
    DirectoryHeader* dh = get_directory_ptr(a);

    bh.flags |= FLAG_DIRECTORY;
    dh.file_count = 0;

    return a;
}

/// read all data, except headers
byte[] read_from_file(Address a) {
    byte[] result;

    BlockHeader* bh = get_block_ptr(a);
    ushort data_index = BlockHeader.sizeof + FileHeader.sizeof;
    if ((bh.flags & FLAG_DIRECTORY) != 0)
        data_index += DirectoryHeader.sizeof;

    result ~= fs_data[a][data_index .. data_index + bh.byte_count];

    Address i = bh.next;
    while (i != a)  //traverse block linked list
    {
        bh = get_block_ptr(i);
        data_index = BlockHeader.sizeof;
        result ~= fs_data[i][data_index .. data_index + bh.byte_count];
        i = bh.next;
    }

    return result;
}

void append(Address a, byte[] data) {

}


void format() {
    // clear all blocks in the fs
    memset(fs_data.ptr, 0, byte.sizeof * BLOCK_COUNT * BLOCK_SIZE);

    // create the root directory as only file
    create_directory("root", 0);
}

void memdmp(string filename) {
    File file = File(filename, "w");

    for (int i = 0; i < BLOCK_COUNT; ++i) {
        file.writefln("Block %d", i);
        file.write(fs_data[i]);
        file.writeln();
    }
}

void save_fs(string filename) {
    File file = File(filename, "wb");
    file.rawWrite(fs_data);
}

void load_fs(string filename) {
    File file = File(filename, "rb");
    file.rawRead(fs_data);
}

