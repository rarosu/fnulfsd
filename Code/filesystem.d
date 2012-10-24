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

const Address E_FILE_NOT_FOUND = 254;
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

    writefln("Creating block at address %d, with previous block %d and next block %d", a, previous, next);
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

    // update parent, only if not root
    if (a != parent) {
        DirectoryHeader* pdh = get_directory_ptr(parent);
        ++pdh.file_count;

        byte[] data = [a];
        append(parent, data);
    }

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

    Address i = bh.next_block;
    while (i != a)  //traverse block linked list
    {
        bh = get_block_ptr(i);
        data_index = BlockHeader.sizeof;
        result ~= fs_data[i][data_index .. data_index + bh.byte_count];
        i = bh.next_block;
    }

    return result;
}

void append(Address a, byte[] data) {
    BlockHeader* bh = get_block_ptr(a);

    ushort offset = BlockHeader.sizeof;
    Address last = bh.previous_block;
    if (last == a) {
        offset += FileHeader.sizeof;
        if ((bh.flags & FLAG_DIRECTORY) != 0)
            offset += DirectoryHeader.sizeof;
    }

    bh = get_block_ptr(last);
    offset += bh.byte_count;

    writefln("Appending data \"%s\" on address %d at offset %d", cast(string)data, a, offset);

    ushort bytes_appended = 0;
    while (bytes_appended < data.length) {
        ushort free_block_space = cast(ushort)(512 - offset);

        int i = 0;
        while (free_block_space != 0) {
            if (bytes_appended == data.length)
                break;
            fs_data[last][offset + i] = data[bytes_appended];
            ++i;
            ++bytes_appended;
            --free_block_space;
        }

        //fs_data[last][offset .. $] = data[bytes_appended .. bytes_appended + free_block_space];
        //bytes_appended += free_block_space;
        bh.byte_count += i;
        if (bytes_appended < data.length) {
            last = create_block(last, a);
            offset = BlockHeader.sizeof;
        }
    }
}

Address find_file_by_name(string filename, Address directory) {
    // truncate filename
    if (filename.length > 32)
        filename = filename[0 .. 32];

    // iterate through all files in the directory
    byte[] files = read_from_file(directory);
    for (int i = 0; i < files.length; ++i) {
        FileHeader* fh = get_file_ptr(files[i]);
        if (fh.name[0 .. filename.length] == filename) {
            return files[i];
        }
    }

    return E_FILE_NOT_FOUND;
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

