module filesystem;

import std.stdio;
import std.c.string;


/+ STRUCTS & TYPEDEFS +/
alias ubyte Address;            // There can only be 250 blocks - one byte is sufficient


// Contains the structure of the metadata that every block needs
struct BlockHeader {
    Address next_block;
    Address previous_block;
    ubyte flags;
    ushort byte_count;
}

// Contains the structure of the metadata that every file needs
struct FileHeader {
    char name[32];          // Design decision: Limit file names to 32 characters
    Address parent_block;
}

// Contains the structure of the metadata that every directory needs
// To be deprecated in fnul fs 2.0
struct DirectoryHeader {
    ubyte file_count;
}

/+ CONSTANTS +/
const ubyte FLAG_ALLOCATED = 0b00000001;        // Set if a block is allocated
const ubyte FLAG_DIRECTORY = 0b00000010;        // Set if a block is a directory

// Error codes. Chosed as impossible addresses for convenience.
const Address E_NOT_A_DIRECTORY = 253;
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

    return cast(FileHeader*) (cast(ubyte*)(get_block_ptr(a)) + BlockHeader.sizeof);
}

DirectoryHeader* get_directory_ptr(Address a) {
    return cast(DirectoryHeader*) (cast(ubyte*)(get_file_ptr(a)) + FileHeader.sizeof);
}

// Linearly iterate through the blocks to find a free one
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
//    fh.name = name;
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

    ushort offset = BlockHeader.sizeof;         // Start writing data after the metadata.
    Address last = bh.previous_block;
    if (last == a) {
        offset += FileHeader.sizeof;
        if ((bh.flags & FLAG_DIRECTORY) != 0)
            offset += DirectoryHeader.sizeof;
    }

    bh = get_block_ptr(last);
    offset += bh.byte_count;

    ushort bytes_appended = 0;
    while (bytes_appended < data.length) {
        ushort free_block_space = cast(ushort)(512 - offset);

        ushort i = 0;
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
        bh = get_block_ptr(bh.next_block);
    }
}

// Since the file system can contain a maximum of 250 files, a directory file will never need more than one block.
// Thus a simpler function without traversing blocks suffices
void clear_directory_data(Address a) {
    BlockHeader* bh = get_block_ptr(a);
    DirectoryHeader* dh = get_directory_ptr(a);

    bh.byte_count = 0;
    memset(dh, 0, (512 - BlockHeader.sizeof - FileHeader.sizeof));
}

// Transform the name from a char array with fixed size to a string with the correct length
string extract_filename(char[] name) {

    string filename = cast(string)name;
    int name_length = name.length;
    for (int k = 0; k < name_length; ++k){
        if (name[k] == 0){
            name_length = k;
            break;
        }
    }

    filename.length = name_length;
    return filename;
}

Address find_file_by_name(string filename, Address directory) {
    BlockHeader* bh = get_block_ptr(directory);
    if ((bh.flags & FLAG_DIRECTORY) == 0)
        return E_NOT_A_DIRECTORY;

    // truncate filename
    if (filename.length > 32)
        filename = filename[0 .. 32];

    // iterate through all files in the directory
    byte[] files = read_from_file(directory);
    for (int i = 0; i < files.length; ++i) {
        FileHeader* fh = get_file_ptr(files[i]);
        string candidate_filename = extract_filename(fh.name);

        if (candidate_filename == filename) {
            return files[i];
        }
    }

    return E_FILE_NOT_FOUND;
}

Address find_directory_by_name(string dirname, Address directory){
    Address a = find_file_by_name(dirname, directory);
    if (a == E_FILE_NOT_FOUND)
        return E_NOT_A_DIRECTORY;

    BlockHeader* bh = get_block_ptr(a);
    if ((bh.flags & FLAG_DIRECTORY) == 0)
        return E_NOT_A_DIRECTORY;

    return a;
}

Address find_file_from_path(string[] path, Address curdir) {
    // Different cases of input:
    //  /fnul/nest/xxx.txt/uuu.txt
    // absolute path
    //  '', 'fnul', 'nest', 'xxx.txt'
    //
    //  fnul/nest/xxx.txt
    // relative path
    // 'fnul','nest','xxx.txt'
    //
    // fnul
    // 'fnul'
    //
    // /fnul/nest/
    // '','fnul','nest',''
    Address get_parent(Address dir) {
        return get_file_ptr(dir).parent_block;
    }

    int start = 0;
    if (path[start] == "") {
        // absolute path
        ++start;
        curdir = 0;
    }

    // Check for trailing slashes
    if (path[$ - 1] == "")
        --path.length;

    for (int i = start; i < path.length; ++i) {
        if (path[i] == ".")
            curdir = curdir;    // traverse to current directory
        else if (path[i] == "..")
            curdir = get_parent(curdir);    // traverse to parent directory
        else {
            curdir = find_file_by_name(path[i], curdir);    // traverse to a subdirectory/file

            // check if illegal path
            if (curdir >= BLOCK_COUNT)
                return curdir;
        }
    }

    return curdir;
}



void rename(Address file, string newname) {
    FileHeader* fh = get_file_ptr(file);

    memset(fh.name.ptr, 0, fh.name.length * char.sizeof);

    if (newname.length > 32)
        fh.name = newname[0 .. 32];
    else
        fh.name[0 .. newname.length] = newname;
}


void format() {
    // clear all blocks in the fs
    memset(fs_data.ptr, 0, byte.sizeof * BLOCK_COUNT * BLOCK_SIZE);

    // create the root directory as only file
    create_directory("root", 0);
}

// Strictly debugging
void memdmp(string filename) {
    File file = File(filename, "w");

    file.writefln("ushort.sizeof = %d", ushort.sizeof);
    file.writefln("ubyte.sizeof = %d", ubyte.sizeof);
    file.writeln();
    file.writefln("Block header size: %d", BlockHeader.sizeof);
    file.writefln("File header size: %d", FileHeader.sizeof);
    file.writefln("Directory header size: %d", DirectoryHeader.sizeof);
    file.writeln();
    for (Address i = 0; i < BLOCK_COUNT; ++i) {
        file.writefln("Block %d", i);

        file.write(fs_data[i][0 .. BlockHeader.sizeof]);
        file.writeln();
        file.write(fs_data[i][BlockHeader.sizeof .. BlockHeader.sizeof + FileHeader.sizeof]);
        file.writeln();
        file.write(fs_data[i][BlockHeader.sizeof + FileHeader.sizeof .. $]);
        file.writeln();
    }
}

// Strictly debugging2
void memdmp2(string filename) {
    File file = File(filename, "w");

    for (Address i = 0; i < BLOCK_COUNT; ++i) {
        BlockHeader* bh = get_block_ptr(i);
        file.writefln("Block %d", i);
        file.writeln(bh.next_block);
        file.writeln(bh.previous_block);
        file.writeln(bh.flags);
        file.writeln(bh.byte_count);
        file.writeln();
        file.write(fs_data[i][BlockHeader.sizeof .. $]);
        file.writeln();

    }
}

void save_fs(string filename) {
    File file = File(filename, "wb");
    file.rawWrite(fs_data);
}

bool load_fs(string filename) {
    try {
        File file = File(filename, "rb");
        file.rawRead(fs_data);

        return true;
    } catch {
        return false;
    }
}

void delete_file(Address file){
    // do not remove root directory.
    if (file == 0)
        return;

    BlockHeader* bh = get_block_ptr(file);
    if ((bh.flags & FLAG_DIRECTORY) != 0) {
        byte[] files = read_from_file(file);
        foreach (Address f; files) {
            delete_file(f);
        }
    }

    FileHeader* fh = get_file_ptr(file);


    // Needs to update the parent directory file to exclude the deleted file
    Address[] siblings = cast(Address[]) read_from_file(fh.parent_block);
    int rem_index = 0;
    for (int i = 0; i < siblings.length; ++i){
        if (siblings[i] == file){
            rem_index = i;
            break;
        }
    }

    siblings = siblings[0 .. rem_index] ~ siblings[rem_index + 1 .. $];
    clear_directory_data(fh.parent_block);
    append(fh.parent_block, cast(byte[]) siblings);

    // The actual deletion
    Address a = file;
    do {
        Address next = bh.next_block;
        bh = get_block_ptr(next);
        memset(fs_data[a].ptr, 0, BLOCK_SIZE * byte.sizeof);
        a = next;
    } while (a != file);

}

string[] extract_path(Address file){
    string[] path;

    while (file != 0){
        FileHeader* fh = get_file_ptr(file);
        path ~= extract_filename(fh.name);
        file = fh.parent_block;
    }

    return path.reverse; // the path is extracted from the working directory and upwards, but typically written out the other way around
}

// Is recursive if a directory is passed as the source file
Address copy(Address source_file, Address target_directory, string target_name) {
    BlockHeader* bh = get_block_ptr(source_file);
    FileHeader* fh = get_file_ptr(source_file);
    Address target_file;

    if ((bh.flags & FLAG_DIRECTORY) != 0) {
        target_file = create_directory(target_name, target_directory);

        Address[] files = cast(Address[]) read_from_file(source_file);

        foreach (Address f; files) {
            FileHeader* ffh = get_file_ptr(f);
            string name = extract_filename(ffh.name);
            copy(f, target_file, name);
        }
    } else {
        target_file = create_file(target_name, target_directory);
        append(target_file, read_from_file(source_file));
    }

    return target_file;
}
