// GDScript-vs-C# benchmark of Helper._value_noise01 (+ _mix64/_cell_hash01),
// written to match GDScript bit for bit (64-bit ints, arithmetic >>).
// Run: dotnet new console -o /tmp/nb && cp noise_bench.cs /tmp/nb/Program.cs
//      && dotnet run -c Release --project /tmp/nb
// The checksum must equal the GDScript loop's (see the plan, Task 1).
using System; using System.Diagnostics;
static class P {
  static long Mix64(long v){ unchecked{ long x=v+ -7046029254386353131L; x=(x^(x>>30))*-4658895280553007687L; x=(x^(x>>27))*-7723592293110705685L; return x^(x>>31);} }
  static double H01(long s,long cx,long cz)=> (double)(Mix64(s^Mix64(cx^Mix64(cz)))&0x7FFFFFFF)/(double)0x80000000L;
  static double Smooth(double t){ t=Math.Clamp(t,0,1); return t*t*(3-2*t);} 
  static double Lerp(double a,double b,double t)=>a+(b-a)*t;
  static double Vn(float px,float pz,long s,double scale){ double x=px/scale,z=pz/scale; long cx=(long)Math.Floor(x),cz=(long)Math.Floor(z); double fx=Smooth(x-cx),fz=Smooth(z-cz);
    return Lerp(Lerp(H01(s,cx,cz),H01(s,cx+1,cz),fx),Lerp(H01(s,cx,cz+1),H01(s,cx+1,cz+1),fx),fz);} 
  static void Main(){ int n=1000000; double acc=0; for(int w=0;w<2;w++){ acc=0; var sw=Stopwatch.StartNew(); for(int i=0;i<n;i++) acc+=Vn((float)((i%1000)*3.7),(float)((i/1000)*3.7),12345,64.0); sw.Stop(); Console.WriteLine($"C#: {sw.Elapsed.TotalMilliseconds*1000/n:F4} us/call sum={acc:F9}"); } }
}
