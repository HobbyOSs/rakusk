use v6;
use Rakusk::Util;

unit role Rakusk::FileFmt::COFF;

my constant IMAGE_SCN_CNT_CODE               = 0x00000020;
my constant IMAGE_SCN_CNT_INITIALIZED_DATA   = 0x00000040;
my constant IMAGE_SCN_CNT_UNINITIALIZED_DATA = 0x00000080;
my constant IMAGE_SCN_MEM_EXECUTE            = 0x20000000;
my constant IMAGE_SCN_MEM_READ               = 0x40000000;
my constant IMAGE_SCN_MEM_WRITE              = 0x80000000;
my constant IMAGE_SCN_ALIGN_1BYTES           = 0x00100000;

my constant SECTION_TEXT_FLAGS = IMAGE_SCN_CNT_CODE +| IMAGE_SCN_MEM_EXECUTE +| IMAGE_SCN_MEM_READ +| IMAGE_SCN_ALIGN_1BYTES;
my constant SECTION_DATA_FLAGS = IMAGE_SCN_CNT_INITIALIZED_DATA +| IMAGE_SCN_MEM_READ +| IMAGE_SCN_MEM_WRITE +| IMAGE_SCN_ALIGN_1BYTES;
my constant SECTION_BSS_FLAGS  = IMAGE_SCN_CNT_UNINITIALIZED_DATA +| IMAGE_SCN_MEM_READ +| IMAGE_SCN_MEM_WRITE +| IMAGE_SCN_ALIGN_1BYTES;

method wrap-wcoff(%symbols, $output, $source_file_name, @global_symbols, @extern_symbols, @relocations = [], @symbol_order = []) {
    my $bin = Buf.new;
    
    # 1. Header (20 bytes)
    # 2. Section Headers (40 bytes each)
    # 3. Section Data
    # 4. Symbol Table (18 bytes each)
    # 5. String Table
    
    my $machine = 0x014c; # i386
    my @section_names = <.text .data .bss>;
    my $num_sections = @section_names.elems;
    
    my $text_size = $output.elems;
    my $data_size = 0;
    my $bss_size = 0;
    
    my $reloc_table_offset = 20 + 40 * $num_sections + $text_size + $data_size;
    # 実際には relocation table offset はセクションごとに異なるが、
    # ここでは .text だけにリロケーションがある前提（Day 09の構成）
    my $reloc_size = @relocations.elems * 10;
    my $symbol_table_offset = $reloc_table_offset + $reloc_size;
    
    # リロケーションがある場合のみオフセットを有効にする
    my $actual_reloc_offset = @relocations.elems > 0 ?? $reloc_table_offset !! 0;
    
    # Symbols: .file, sections, then globals/externs
    my @syms;
    # .file symbol
    @syms.push({ name => ".file", value => 0, section => -2, storage => 103, aux => self.pack-str-pad($source_file_name, 18) });
    # section symbols
    for 1..$num_sections -> $i {
        my $num_relocs = ($i == 1 ?? @relocations.elems !! 0);
        my $sec_size = do given $i {
            when 1 { $text_size }
            when 2 { $data_size }
            when 3 { $bss_size }
            default { 0 }
        };
        @syms.push({ 
            name => @section_names[$i-1], 
            value => 0, 
            section => $i, 
            storage => 3, 
            aux => pack-le($sec_size, 32) 
                 ~ pack-le($num_relocs, 16) 
                 ~ pack-le(0, 16) # NumberOfLinenumbers
                 ~ pack-le(0, 32) # Checksum
                 ~ pack-le($i, 16) # Section number (1-based)
                 ~ pack-le(0, 8)  # Selection
                 ~ Buf.new(0 xx 3) # Unused
        });
    }
    
    my @all_externs = @extern_symbols.unique;
    my @all_globals = @global_symbols.unique;

    for @all_externs -> $name {
        @syms.push({ name => $name, value => 0, section => 0, storage => 2 });
    }
    for @all_globals -> $name {
        my $val = %symbols{$name} // 0;
        @syms.push({ name => $name, value => $val, section => 1, storage => 2 });
    }
    
    my $num_symbols = 0;
    my $symbol_table_bin = Buf.new;
    my $string_table_bin = Buf.new;
    
    # 文字列テーブルの事前構築
    # 順序: 定義順 (@symbol_order) のうち 8文字超のもの
    my %name_offsets;
    for @symbol_order -> $name {
        if $name.chars > 8 && !%name_offsets{$name}.defined {
            %name_offsets{$name} = $string_table_bin.elems + 4;
            $string_table_bin.append($name.encode('ascii'));
            $string_table_bin.push(0);
        }
    }

    for @syms -> $s {
        my $name_bin;
        if %name_offsets{$s<name>}.defined {
            $name_bin = pack-le(0, 32) ~ pack-le(%name_offsets{$s<name>}, 32);
        } else {
            # 8文字以下の場合は直接格納、それ以外は通常通り (ただし事前構築済みのはず)
            $name_bin = self.coff-name($s<name>, $string_table_bin);
        }
        $symbol_table_bin ~= $name_bin;
        $symbol_table_bin ~= pack-le($s<value>, 32);
        $symbol_table_bin ~= pack-le($s<section>, 16);
        $symbol_table_bin ~= pack-le(0, 16); # Type
        $symbol_table_bin ~= pack-le($s<storage>, 8);
        $symbol_table_bin ~= pack-le($s<aux> ?? 1 !! 0, 8);
        $num_symbols++;
        
        if $s<aux> {
            $symbol_table_bin ~= $s<aux>;
            $num_symbols++;
        }
    }
    
    # Final assembly
    $bin ~= pack-le($machine, 16);
    $bin ~= pack-le($num_sections, 16);
    $bin ~= pack-le(0, 32); # TimeDateStamp
    $bin ~= pack-le($symbol_table_offset, 32);
    $bin ~= pack-le($num_symbols, 32);
    $bin ~= pack-le(0, 16); # SizeOfOptionalHeader
    $bin ~= pack-le(0, 16); # Characteristics
    
    # Section Headers
    # .text
    $bin ~= self.coff-name(".text");
    $bin ~= pack-le(0, 32); # VirtualSize
    $bin ~= pack-le(0, 32); # VirtualAddress
    $bin ~= pack-le($text_size, 32);
    $bin ~= pack-le(20 + 40 * $num_sections, 32); # PointerToRawData
    $bin ~= pack-le($actual_reloc_offset, 32); # PointerToRelocations
    $bin ~= pack-le(0, 32); # PointerToLinenumbers
    $bin ~= pack-le(@relocations.elems, 16); # NumberOfRelocations
    $bin ~= pack-le(0, 16); # NumberOfLinenumbers
    $bin ~= pack-le(SECTION_TEXT_FLAGS, 32); # Characteristics
    
    # .data (empty)
    $bin ~= self.coff-name(".data");
    $bin ~= pack-le(0, 32); $bin ~= pack-le(0, 32);
    $bin ~= pack-le(0, 32); $bin ~= pack-le(0, 32);
    $bin ~= pack-le(0, 32); $bin ~= pack-le(0, 32);
    $bin ~= pack-le(0, 16); $bin ~= pack-le(0, 16);
    $bin ~= pack-le(SECTION_DATA_FLAGS, 32);
    
    # .bss (empty)
    $bin ~= self.coff-name(".bss");
    $bin ~= pack-le(0, 32); $bin ~= pack-le(0, 32);
    $bin ~= pack-le(0, 32); $bin ~= pack-le(0, 32);
    $bin ~= pack-le(0, 32); $bin ~= pack-le(0, 32);
    $bin ~= pack-le(0, 16); $bin ~= pack-le(0, 16);
    $bin ~= pack-le(SECTION_BSS_FLAGS, 32);
    
    # Raw Data
    $bin ~= $output;

    # Relocations
    for @relocations -> $r {
        $bin ~= pack-le($r<offset>, 32);
        $bin ~= pack-le($r<sym_idx>, 32);
        $bin ~= pack-le($r<type>, 16); # 20 = REL_I386_REL32
    }
    
    # Symbol Table
    $bin ~= $symbol_table_bin;
    
    # String Table
    $bin ~= pack-le($string_table_bin.elems + 4, 32);
    $bin ~= $string_table_bin;
    
    return $bin;
}

method coff-name($name, $string_table?) {
    if $name.chars <= 8 {
        my $bin = $name.encode('ascii');
        my @bytes = $bin.list;
        @bytes.push(0) while @bytes.elems < 8;
        return Buf.new(@bytes);
    } else {
        die "Long names requires string_table" unless $string_table.defined;
        my $offset = $string_table.elems + 4;
        $string_table.append($name.encode('ascii'));
        $string_table.push(0);
        return pack-le(0, 32) ~ pack-le($offset, 32);
    }
}

method pack-str-pad($s, $len) {
    my $bin = $s.encode('ascii');
    my @bytes = $bin.list;
    if @bytes.elems > $len {
        @bytes = @bytes[0..($len-1)];
    } else {
        @bytes.push(0) while @bytes.elems < $len;
    }
    return Buf.new(@bytes);
}
