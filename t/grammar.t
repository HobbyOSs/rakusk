use v6;
use Test;
use Rakusk::Grammar;

plan *;

my @test-cases = (
    # Basic instructions
    { input => "mov rax, rbx", desc => "basic mov" },
    { input => "add eax, 10", desc => "add with immediate" },
    { input => "push rbp", desc => "unary instruction" },
    { input => "ret", desc => "no-operand instruction" },

    # Immediates
    { input => "mov rax, 0x123", desc => "hex immediate" },
    { input => "mov rax, 123", desc => "decimal immediate" },
    { input => "mov rax, -123", desc => "negative immediate" },

    # Addressing modes
    { input => "mov rax, [rbx]", desc => "indirect" },
    { input => "mov rax, [rbx + 8]", desc => "offset" },
    { input => "mov rax, [rbx - 8]", desc => "negative offset" },
    { input => "mov rax, [rbx + rcx]", desc => "indexed" },
    { input => "mov rax, [rbx + rcx * 4]", desc => "scaled indexed" },
    { input => "mov rax, [rbx + rcx * 8 + 16]", desc => "complex addressing" },
    { input => "lea rax, [rip + label]", desc => "RIP relative" },
    { input => "mov [rax + rbx*4 + 8], 1", desc => "store immediate to memory" },

    # Directives
    { input => ".section .text", desc => "section directive" },
    { input => ".global _start", desc => "global directive" },
    { input => ".byte 1, 2, 3", desc => "byte directive multiple values" },
    { input => ".word 0x1234, 0x5678", desc => "word directive multiple values" },
    { input => ".long 1, 2, 3", desc => "long directive multiple values" },
    { input => ".quad 0x1234567890abcdef", desc => "quad directive" },
    { input => ".ascii \"hello\"", desc => "ascii directive" },
    { input => ".asciz \"hello\"", desc => "asciz directive" },
    { input => ".skip 1024", desc => "skip directive" },

    # Labels and symbols
    { input => "_start:", desc => "label definition" },
    { input => "jmp _start", desc => "jump to symbol" },
    { input => "call printf", desc => "call symbol" },
    { input => "loop: mov al, [rsi]", desc => "label and instruction" },

    # Comments and whitespace
    { input => "  mov rax, rbx  ", desc => "leading/trailing whitespace" },
    { input => "mov rax, rbx # comment", desc => "end of line comment" },
    { input => "# full line comment", desc => "full line comment" },
    { input => "", desc => "empty line" },
);

for @test-cases -> %tc {
    ok Rakusk::Grammar.parse(%tc<input>), %tc<desc> // %tc<input>;
}

done-testing;
