// Exact mirror of LandformFeatures.local_*; memo entries are immutable.
using System;
using static Story.Native.GdMath;
namespace Story.Native
{
    internal sealed class LocalForm
    {
        public bool Present, Hollow;
        public V2 Pos;
        public V2[] Nodes=Array.Empty<V2>();
        public double Angle, Height, Bend, Offset;
    }
    internal sealed partial class SeedField
    {
        static readonly double[] LocalCrestHeights={.84,1,.9};
        readonly Memo<LocalForm> _localForms = new(1 << 14);
        LocalForm LocalCandidate(long x, long z)
        {
            long key = Memo<LocalForm>.Key(x,z);
            if (_localForms.TryGet(key,out var cached)) return cached;
            double H(long salt) => CellHash01(Seed+salt,x,z);
            var f = new LocalForm();
            if (H(2310) > .94) return _localForms.Store(key,f);
            V2 pos = (new V2((float)x,(float)z)+V2.D(.25+.5*H(2311),.25+.5*H(2312)))*T.LOCAL_CELL;
            if (pos.Length()-T.LOCAL_RADIUS < T.F_SPAWN_CLEAR_M) return _localForms.Store(key,f);
            f.Present=true; f.Pos=pos; f.Angle=Grain(pos)+(H(2313)-.5)*.8;
            f.Height=Lerp(T.LOCAL_HEIGHT_MIN,T.LOCAL_HEIGHT_MAX,H(2314));
            f.Hollow=H(2315)<.4; f.Bend=(H(2316)-.5)*48; f.Offset=(H(2317)-.5)*35;
            f.Nodes=new[]{V2.D(-64,-f.Bend*.4),V2.D(0,f.Bend),V2.D(64,-f.Bend*.6)};
            return _localForms.Store(key,f);
        }
        static double LocalDome(V2 p,double a,double b)
        {
            double t=V2.D(p.X/a,p.Y/b).LengthSquared();
            return Math.Pow(Math.Max(0,1-t),2);
        }
        double LocalShape(LocalForm f,V2 p)
        {
            V2 q=(p-f.Pos).Rotated(-f.Angle);
            if(q.Length()>=T.LOCAL_RADIUS)return 0;
            if(f.Hollow)
            {
                double bowl=LocalDome(q,132,78);
                double bridge=1-Smoothstep(9,27,Math.Abs(q.X-f.Offset));
                double island=Math.Max(LocalDome(q-V2.D(-48,27),27,23),LocalDome(q-V2.D(49,-26),30,24));
                return -f.Height*bowl*(1-Math.Max(bridge,island));
            }
            V2[] nodes=f.Nodes;
            double[] heights=LocalCrestHeights;
            double result=0;
            for(int i=0;i<3;i++)result=Math.Max(result,heights[i]*LocalDome(q-nodes[i],50,43));
            for(int i=0;i<2;i++)
            {
                V2 a=nodes[i], b=nodes[i+1], axis=b-a;
                double t=Clamp((double)(q-a).Dot(axis)/(double)axis.LengthSquared(),0,1);
                double distance=q.DistanceTo(a+axis*t);
                double crest=Lerp(heights[i],heights[i+1],t)*(1-.42*Math.Sin(Math.PI*t)*Math.Sin(Math.PI*t));
                result=Math.Max(result,crest*Math.Pow(Math.Max(0,1-Math.Pow(distance/43,2)),2));
            }
            return f.Height*result;
        }
        double LocalRelief(V2 p)
        {
            // GDScript divides a Vector2 before floor: preserve that float32 step.
            V2 cell=p/T.LOCAL_CELL;
            long cx=Floori(cell.X),cz=Floori(cell.Y);
            double raised=0,cut=0;
            for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++)
            {
                var f=LocalCandidate(cx+x,cz+z);
                if(!f.Present)continue;
                double v=LocalShape(f,p);
                raised=Union(raised,Math.Max(0,v));cut=Union(cut,Math.Max(0,-v));
            }
            return raised-cut;
        }
    }
}
