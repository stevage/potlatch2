package net.systemeD.potlatch2.tools
{
    
    import net.systemeD.halcyon.connection.*;
    import net.systemeD.halcyon.connection.actions.SplitWayAction;
	public class MagicRoundabout
	{
		private var node: Node;
		private var radius: Number;
		private var connection: Connection;
		private var performAction: Function;
		/** Creates a roundabout, forms junctions, removes the internal ways, and sets tags. All in one sweet tool. 
		 * @param initNode The location that the roundabout will be centred around. Any ways connected to this node will be split.
		 * @param initRadius Radius of roundabout, in map coords.
		 * @param performAction The usual undo stack thing. */
		public function MagicRoundabout(node: Node, radius: Number, performAction:Function) {
			this.node = node;
			this.radius = radius;
			this.performAction = performAction;
			connection = Connection.getConnectionInstance();
			
            var nodes: Array = makeCircle();
            var way_tags:Object = findWayTags();
            
            var way:Way = connection.createWay(way_tags, nodes, performAction);
            
            // Split any ways that cross the centre of the roundabout.
            for each (var w: Way in node.parentWays) {
            	if (!w.endsWith(node))
            	  performAction(new SplitWayAction(w, w.indexOfNode(node)));
            }
            
            doJunctions(way);
		
        }
		
		private function makeCircle():Array {
            // Pick a number of nodes vaguely in proportion to the size of circle
            var num_nodes: int = Math.pow(radius, 1/2) * 1000;
            var nodes:Array = [];
            // Go around the circle, creating nodes. The .0001 is to avoid floating point
            // inaccuracy leading to a duplicated final node.
            for (var a:Number = 0; a < Math.PI * 2-.0001; a += Math.PI * 2 / num_nodes) {
                var n: Node = connection.createNode(
                   {},
                   Node.latp2lat(node.latp + Math.sin(a) * radius), // Use latp to get round circles
                   node.lon + Math.cos(a) * radius,
                   performAction);
                nodes.push(n); 
            }
            nodes.push(nodes[0]); // join the loop
            nodes = nodes.reverse(); // TODO get the direction right in both halves of the world
            /* Work out what tags to put on the roundabout. Basically, the highest level road touching the node we started from. */
            return nodes;
		}
		
		private function findWayTags():Object {
            var max_highway: int = -1;
            var highway_hierarchy: Array = ["track", "service", "residential", "unclassified", "tertiary_link", "tertiary", 
            "secondary_link", "secondary", "primary_link", "primary", "trunk_link", "trunk", "motorway_link", "motorway"];


            var fallback_highway_tag: String = null;
            for each (var w: Way in node.parentWays) {
                max_highway = Math.max(max_highway, highway_hierarchy.indexOf(w.getTag("highway")));
                if (w.getTag("highway")) // maybe there's a highway=cycleway or something
                   fallback_highway_tag = w.getTag("highway");
            }
            var way_tags: Object = { junction: "roundabout" };
            if (max_highway > -1)
                way_tags.highway = highway_hierarchy[max_highway];
            else {
                if (fallback_highway_tag)
                   way_tags.highway = fallback_highway_tag;
                else
                    way_tags.highway = "residential";
            }
            return way_tags;

		}
		
		private function doJunctions(way: Way):void {
/*          
            // This is an altenative algorithm to what's below. I think
            // they both work. This splits any ways that touch the centre of the roundabout
            // then removes all the nodes
            // between there and the centre.
            
            var junctions: Array = new MakeJunctions(way, true).run();
            
            for each (var j: Node in junctions) {
                for each (var w: Way in j.parentWays) {
                    if (w.indexOfNode(node) < 0)
                      continue;
                    if (w.indexOfNode(node) > w.indexOfNode(j)) {
                        w.deleteNodesFrom(w.indexOfNode(node), performAction);
                    }  else {
                        w.deleteNodesTo(w.indexOfNode(j)-1, performAction);
                    }
                }
            }
            
  */          
            
            // Form junctions where the roundabout hits other ways.
            var junctions: Array = new MakeJunctions(way, performAction, true).run();
            // Now find any of those ways that connected with the centre of the roundabout.
            for each (var j: Node in junctions) {
                for each (var w: Way in j.parentWays) {
                    if (w.indexOfNode(node) < 0)
                      continue;
                    
                    // Split it...
                    performAction(new SplitWayAction(w, w.indexOfNode(j)));
                    // Now j has three parent ways. We find the one that leads back to our home node, and delete it.
                    for each (var w2:Way in j.parentWays) {
                        if (w2.indexOfNode(node) >= 0) {
                            w2.remove(performAction);
                            break;
                        }
                    }
                }
            }
			
		}

	}
}