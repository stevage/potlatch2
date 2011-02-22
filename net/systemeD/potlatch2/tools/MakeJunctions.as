package net.systemeD.potlatch2.tools {
    import flash.geom.Point;
    import flash.geom.Rectangle;
    
    import net.systemeD.halcyon.connection.*;
	
	/** Tool that automatically creates junctions between the given way and any ways that it crosses. */
	public class MakeJunctions	{
		private var way: Way;
		private var connection: Connection;
		private var allWays: Array;
		private var onlyTransportTags: Boolean;
		/** Slowly (!) looks for intersections between the given way and others (optionally filtered), then creates junctions for them all. 
		 * Don't even think about calling this multiple times per second. It has O(NM) running time where N is the number of segments in the
		 * test way, and M is the total number of segments of all other ways in its bounding box. Performance is adequate for non-pathological
		 * cases. */
		public function MakeJunctions(initWay: Way, initOnlyTransportTags: Boolean = true) {
			way = initWay;
			onlyTransportTags = initOnlyTransportTags;
			fetchWays();
			
			var p0: Point = way.getNode(i).lonlat;
			var intersections: Array=[];
			for (var i: uint = 1; i < way.length; i++) {
			   var p1: Point = way.getNode(i).lonlat;
			   intersections = intersections.concat(FindIntersectionsForSegment(p0,p1));
			   p0 = p1;
			}
			for each (var intersection:Object in intersections) {
	            var undo:CompositeUndoableAction = new CompositeUndoableAction("Auto-create junction");
	            var node:Node = connection.createNode({}, intersection.lat, intersection.lon, undo.push);
	            var index:int = way.insertNodeAtClosestPosition(node, false, undo.push);
	            intersection.w.insertNodeAtClosestPosition(node, false, undo.push);
	            MainUndoStack.getGlobalStack().addAction(undo);
	        }
		}
		
		/** Pre-fetch all the ways that the target way could cross, and filter them down if necessary. */
		protected function fetchWays():void {
			connection = Connection.getConnectionInstance();
            var r:Rectangle = way.boundingBox;
            allWays = connection.getObjectsByBbox(r.x, r.x+r.width, r.y, r.y-r.height, true, false).waysInside;
            // probably user only wants junctions between roads and similar. the list below is not comprehensive.
            if (onlyTransportTags) {
                for (var i: uint = 0; i < allWays.length; i++) {
                	if (!allWays[i].getTag("highway") 
                	 && !allWays[i].getTag("railway")
                     && !allWays[i].getTag("aeroway")
                	) {
                		allWays.splice(i--,1);
                	}
                }
            }
		}
		
		/** Returns the location of the intersection between segments (p0,p1) and (p2,p3), or null. 
		 From http://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect, 
		originally from Andre LeMothe's "Tricks of the Windows Game Programming Gurus". */
		public static function SegmentIntersection(p0: Point, p1: Point, p2: Point, p3: Point): Point {
		    var s1: Point = new Point (p1.x - p0.x, p1.y - p0.y);
		    var s2: Point = new Point (p3.x - p2.x, p3.y - p2.y);
		    
		    var s: Number = (-s1.y * (p0.x - p2.x) + s1.x * (p0.y - p2.y)) / (-s2.x * s1.y + s1.x * s2.y);
		    var t: Number = ( s2.x * (p0.y - p2.y) - s2.y * (p0.x - p2.x)) / (-s2.x * s1.y + s1.x * s2.y);
		
		    if (s >= 0 && s <= 1 && t >= 0 && t <= 1) {
		        // Intersection detected
		        return new Point (p0.x + (t * s1.x), p0.y + (t * s1.y));
		    }
		
		    return null; // No intersection
	    }
		
	
		/** Given a segment defined by these two points, returns an array of intersections between that segment and any ways in allWays. */ 
		protected function FindIntersectionsForSegment(p0: Point, p1: Point): Array {
			var left: Number = Math.min(p0.x, p1.x);
            var right: Number = Math.max(p0.x, p1.x);
            var top: Number = Math.max(p0.y, p1.y);
            var bottom: Number = Math.min(p0.y, p1.y);
			var junctions: Array = [];
			var pr:Rectangle = new Rectangle(
                       Math.min(p0.x,  p1.x),
                       Math.min(p0.y,  p1.y),
                       Math.abs(p0.x - p1.x),
                       Math.abs(p0.y - p1.y));
			
			for each (var w:Way in allWays) {
				if (w.length < 2) continue;
				if (w == way) continue; // TODO allow self-junctions
				var q0: Point = w.getNode(0).lonlat;
				for (var i: uint = 1; i < w.length; i++) {
					var q1:Point = w.getNode(i).lonlat;
					var qr: Rectangle = new Rectangle(
					   Math.min(q0.x, q1.x),
					   Math.min(q0.y, q1.y),
					   Math.abs(q0.x - q1.x),
					   Math.abs(q0.y - q1.y));
					
					// This should be a useful optimisation, but it returns false negatives. I'm not sure why.
					// In my cursor investigation, some false negatives had rectangles of zero width. *shrug*
					// TODO fix and reinstate
					if (true || qr.intersects(pr)) {
						// potential intersection, now compute it
						var z: Point = SegmentIntersection(p0, p1, q0, q1);
						if (z) {
							// check whether there is already a junction between these two ways near here
							const epsilon2:Number = 0.00001 // arbitrary definition of "near here"
							var makejunction:Boolean = true;
							for each (var n: Node in way.getJunctionsWith(w)) {
								if ( Math.pow(n.lat - z.y, 2) + Math.pow(n.lon - z.x, 2) < epsilon2) {
									makejunction = false; break;
								}  
							}
							if (makejunction) {
								var obj = {w: w, lat: z.y, lon: z.x};
								junctions.push(obj);
								/*if (!qr.intersects(pr)) {
									trace(qr + " doesn't intersect " + pr);
									trace("But intersection found at ", obj.lat,  ", " , obj.lon);
									
								}*/
							}
						}
					}
					q0=q1;
					
				}
			}
		    return junctions;
		}

	}
}