export const font={A:['010','101','111','101','101'],B:['110','101','110','101','110'],C:['011','100','100','100','011'],D:['110','101','101','101','110'],E:['111','100','110','100','111'],F:['111','100','110','100','100'],G:['011','100','101','101','011'],H:['101','101','111','101','101'],I:['111','010','010','010','111'],J:['001','001','001','101','010'],K:['101','101','110','101','101'],L:['100','100','100','100','111'],M:['101','111','111','101','101'],N:['101','111','111','111','101'],O:['010','101','101','101','010'],P:['110','101','110','100','100'],Q:['010','101','101','111','011'],R:['110','101','110','101','101'],S:['011','100','010','001','110'],T:['111','010','010','010','010'],U:['101','101','101','101','111'],V:['101','101','101','101','010'],W:['101','101','111','111','101'],X:['101','101','010','101','101'],Y:['101','101','010','010','010'],Z:['111','001','010','100','111'],'-':['000','000','111','000','000'],' ':['000','000','000','000','000'],'0':['111','101','101','101','111'],'1':['010','110','010','010','111'],'2':['110','001','010','100','111'],'3':['110','001','010','001','110'],'4':['101','101','111','001','001']};
export const srgbByte=v=>Math.round((v/255<=.0031308?12.92*v/255:1.055*(v/255)**(1/2.4)-.055)*255);
export function sheet(items,cols=6,tile=128){
  const cell=tile+12,row=tile+30,width=cols*cell,height=Math.ceil(items.length/cols)*row,data=new Uint8Array(width*height*4);
  for(let i=0;i<data.length;i+=4)data.set([25,28,31,255],i);
  for(const [index,item]of items.entries()){
    const ox=index%cols*cell+6,oy=Math.floor(index/cols)*row+6;
    if(item.image){const a=item.image;for(let y=0;y<tile;y++)for(let x=0;x<tile;x++){
      const sx=Math.floor(x*a.width*(item.repeat??1)/tile)%a.width,sy=Math.floor(y*a.height*(item.repeat??1)/tile)%a.height,i=(sy*a.width+sx)*4,j=((oy+y)*width+ox+x)*4;
      for(let c=0;c<3;c++)data[j+c]=item.linear?srgbByte(a.data[i+c]):a.data[i+c];
    }}
    for(const [line,text]of item.label.split('\n').entries())for(const [ci,char]of [...text.toUpperCase()].entries())for(const [y,bits]of (font[char]??font[' ']).entries())for(let x=0;x<3;x++)if(bits[x]==='1'&&ci*4+x<tile)data.set([225,230,230,255],((oy+tile+4+line*7+y)*width+ox+ci*4+x)*4);
  }
  return {width,height,data};
}
