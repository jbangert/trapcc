
#include <stdint.h>
#undef VERBOSE
	
typedef volatile struct __tss_struct { /* For GDB only */
    unsigned short   link;
    unsigned short   link_h;

    unsigned int   esp0;
    unsigned short   ss0;
    unsigned short   ss0_h;

    unsigned int   esp1;
    unsigned short   ss1;
    unsigned short   ss1_h;

    unsigned int   esp2;
    unsigned short   ss2;
    unsigned short   ss2_h;

    unsigned int   cr3;
    unsigned int   eip;
    unsigned int   eflags;

    unsigned int   eax;
    unsigned int   ecx;
    unsigned int   edx;
    unsigned int    ebx;

    unsigned int   esp;
    unsigned int   ebp;

    unsigned int   esi;
    unsigned int   edi;

    unsigned short   es;
    unsigned short   es_h;

    unsigned short   cs;
    unsigned short   cs_h;

    unsigned short   ss;
    unsigned short   ss_h;

    unsigned short   ds;
    unsigned short   ds_h;

    unsigned short   fs;
    unsigned short   fs_h;

    unsigned short   gs;
    unsigned short   gs_h;

    unsigned short   ldt;
    unsigned short   ldt_h;

    unsigned short   trap;
    unsigned short   iomap;

} tss_struct;	
	
#define	PG_P 0x001
#define PG_W 0x002
#define PG_U 0x004
/* Skip cache stuff */
#define PG_A 0x020
#define	PG_M 0x040
#define	PG_PS 0x080
#define	PG_G 0x100

/* Multiboot parameters*/
extern uint32_t magic;
extern void *mbd;


/* Screen printing */
#define NUM_LINES 24
#define NUM_CHARS 80
int g_x=1,g_y=1;
static inline void setchar(unsigned int line, unsigned int off, unsigned char character){
   unsigned char *videoram = (unsigned char *)0xB8000;
   videoram[line * NUM_CHARS * 2+2*off] = character; /* character 'A' */
   videoram[line * NUM_CHARS * 2+ 2 *off + 1] = 0x07; /* light grey (7) on black (0). */
}
static inline void clear_screen(){
  for(int l=0;l<24;l++){
    for(int c=0;c<80;c++){
      setchar(l,c,' ');
    }
  }
  g_x=g_y=0;
}
static inline void next_line()
{
  g_x = 0;
   if(++g_y == NUM_LINES)
     g_y = 0; 
}
static inline void print_character(unsigned char x){  
  if(++g_x == NUM_CHARS)
    next_line();
  setchar(g_y,g_x,x);
}
static inline void hex_digit(unsigned char digit){
  if(digit < 10)
    print_character(digit + '0');
  else 
    print_character(digit + 'A' - 10);
}
static inline void hex_byte(unsigned char byte){
  hex_digit(byte >> 4);
  hex_digit(byte & 0xF);
}
static inline void hex_word(unsigned short word){
  hex_byte(word >> 8);
  hex_byte(word & 0xFF);
}
static inline void hex_dword(unsigned int word){
  hex_word(word >> 16);
  hex_word(word & 0xFFFF);

}
static inline void bin_dword(unsigned int word){
  for(int i = 32;i>0;i--){
    if(word & 0x80000000)
      print_character('1');
    else
      print_character('0');
    word <<= 1;
  }  
}
static inline void print_string( char * data){
  while(*data != 0){
    if(*data == '\n')
      next_line();
    else
      print_character(*(unsigned char *)data);
    data++;
  }
}
#define PRINT_STRING(x)  {char str## __LINE__ [] = x; print_string (str ## __LINE__);}
#define PRINT_STRING2(x)  {char str2## __LINE__ [] = x; print_string (str2 ## __LINE__);}
#define DEBUG_ADDR(x) {PRINT_STRING("Contents of "#x"("); hex_dword((unsigned int)x); PRINT_STRING2(") are:"); hex_dword(*(unsigned int *)x); next_line(); }

/* Utility functions, copied from FreeBSD*/
typedef unsigned int u_int;
typedef unsigned char u_char;
typedef unsigned short u_short;
void load_cr0(u_int data)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (data) : "memory");
}

u_int rcr0(void)
{
	u_int	data;

	__asm __volatile("movl %%cr0,%0" : "=r" (data));
	return (data);
}
u_int rcr2(void)
{
	u_int	data;

	__asm __volatile("movl %%cr2,%0" : "=r" (data));
	return (data);
}
void load_cr3(u_int data)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (data) : "memory");
}

u_int rcr3(void)
{
	u_int	data;

	__asm __volatile("movl %%cr3,%0" : "=r" (data));
	return (data);
}

u_int reflags(void)
{
	u_int	data;

	__asm __volatile("pushf \n pop %0" : "=r" (data));
	return (data);
}

void
load_cr4(u_int data)
{
	__asm __volatile("movl %0,%%cr4" : : "r" (data));
}

 u_int
rcr4(void)
{
	u_int	data;

	__asm __volatile("movl %%cr4,%0" : "=r" (data));
	return (data);
}
 u_int
rsp(void)
{
	u_int	data;

	__asm __volatile("movl %%esp,%0" : "=r" (data));
	return (data);
}

/* End FreeBSD */


/* GDT, TSS */
#define GDT_ADDRESS 0x01800000
typedef unsigned char gdt_entry[8];
gdt_entry *g_gdt = (gdt_entry *)GDT_ADDRESS;
char g_tss[104];
unsigned int g_tss_ptr= 0;
extern void asmSetGDTR(void *GDT,unsigned int size);
extern void asmSetIDTR(void *IDT,unsigned int size);
#define PAGE_OFFSET(x) (x* (1ul<<12))
#define HUGEPAGE_OFFSET(x) (x * (1ul << 22))
#define IDT_ADDRESS 0x1000000
#define MAX_PDES 32
#define MAX_MEMORY HUGEPAGE_OFFSET(MAX_PDES) // 128 MB ram mapped directly
#define PAGE_DIRECTORY (MAX_MEMORY - HUGEPAGE_OFFSET(1)) // Start pagetables at 124 MB ram.
#define MAP_PAGE(virt,phys) pde[virt]= (phys << 22) | PG_P | PG_W | PG_U | PG_PS;

void init_paging(){
  int *pde = (int *)PAGE_DIRECTORY;
  for(int i=0;i<MAX_PDES;i++){ //Direct mapping
    MAP_PAGE(i,i);
  }
  load_cr3((u_int)pde);
  load_cr4(rcr4() | 0x10);
  //load_cr4(rcr4() |  0x00000080);      /* Page global enable */
  load_cr0(rcr0()  | (1<<31));
}
static inline void encode_gdt(gdt_entry t,unsigned char type,
			      unsigned int base,
			      unsigned int limit)
{
  limit = limit >> 12;
  ((u_short *)t)[0]=(unsigned short) limit& 0xFFFF;
  ((u_short *)t)[1]= base & 0xFFFF;
  t[4] = (unsigned char) (base >> 16) ;
  t[5] =  (unsigned char) type;
  t[6] =  (unsigned char) 0xC0 | (unsigned char)(limit>>16); /* 32 bit and page granular */
  t[7] =  (unsigned char)(base >> 24) ;
}
#define TSS_ALIGN -48
static inline void init_gdt(){
  int i,j;
  for(i=0;i<8192;i++)
    *((unsigned long *)&g_gdt[i]) = 0; 
  encode_gdt(g_gdt[1],0x9A,0,0xFFFFFFFF); /* code 0x08*/
  encode_gdt(g_gdt[2],0x92,0,0xFFFFFFFF); /* data 0x10 */
  encode_gdt(g_gdt[3],0x89,g_tss_ptr,0xFFFFFF); /*TSS0 0x18*/ 
  asmSetGDTR(g_gdt,0xFFFF);    /* sets TSS to 0x18*/
  for(j=0;j<16;j++){ //TODO: Re-increase
    i = (j * 0x1000 +  0xFF8) / 8;
    encode_gdt(g_gdt[i],0x89,1024 * 4096  + j *65536 + TSS_ALIGN,0xFFFFFF);/* See interrupt_program.rb */
  }
  // encode_gdt(g_gdt[(0xFFE0/8)],0x9A,0,0xFFFFFE00); /* Causes GPF*/
}
static inline void init_tss(){ /* TODO: refactor */
  g_tss_ptr = (u_int) &g_tss;
  *((u_int *)(g_tss + 28)) = PAGE_DIRECTORY;
}

static void interrupt_program();
static void begin_computation();
void kmain(void)
{  
   if ( magic != 0x2BADB002 )
  {
    while(1){}
   }
   u_int lower_mem = ((unsigned int*)mbd)[1];
   u_int higher_mem = ((unsigned int*)mbd)[1];  
   
   clear_screen();
   init_paging();   
   PRINT_STRING("We are now paging\n");
   init_tss();
   PRINT_STRING("We have a TSS\n");
   init_gdt();
   PRINT_STRING("And loaded a GDT\n");   
   //init_idt();
   //PRINT_STRING("And it's neighbour the IDT\n");4
   PRINT_STRING("Let's party!\n");
   interrupt_program();
   asmSetIDTR(IDT_ADDRESS,256*8 - 1);
   /* Pagefault. this will save the TSS state*/
   // begin_computation();
   begin_computation();
   __asm __volatile ("lcall  $0x30, $0x0");
   //lcr3(INIT_PAGETABLE);
   PRINT_STRING("How the hell did we get here?");
   while(1){}
}

void memset(void *s,int c,unsigned int sz){
  char *data = (char *)s;
  while(sz> 0){
    sz--;
    *(data++)  = (unsigned char )c;
  }
}
u_int *_tmp[4096];
/* STANDALONE specific code */
#define ALLOC_PTEPTR_ARRAY() _tmp /* Allocation is used only once */
/* TODO: Free */
#define PFN2VIRT(x) ((char *)(x<<12))
#define VIRT2PFN(x) (((u_int)x)>>12)
const u_int base_pfn = 0;
