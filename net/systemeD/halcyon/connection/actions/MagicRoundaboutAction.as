package net.systemeD.halcyon.connection.actions
{
	import net.systemeD.halcyon.connection.CompositeUndoableAction;
	import net.systemeD.halcyon.connection.actions.SplitWayAction;
	import net.systemeD.halcyon.connection.*;
	import net.systemeD.potlatch2.tools.MakeJunctions;

	/** Creates a roundabout, forms junctions, removes the internal ways, and sets tags. All in one sweet action.*/
	public class MagicRoundaboutAction extends CompositeUndoableAction
	{
        private var node: Node;
        private var radius: Number;
        private var connection: Connection;
        protected var _createdWay: Way;
        public function get createdWay():Way { return _createdWay; }

		public function MagicRoundaboutAction(node: Node, radius: Number)
		{
			super('Magic roundabout');
            this.node = node;
            this.radius = radius;
            connection = Connection.getConnectionInstance();
		}
		
		private function performAction(action: UndoableAction):void { 
		  action.doAction(); push(action); 
		}
        
        public override function doAction():uint {
            if (actionsDone) return UndoableAction.FAIL;;
            if ( actions.length > 0 ) {
            	// Assume that this is a redo: replay the previously calculated actions.
            	return super.doAction();
            }
                
            var nodes: Array = makeCircle();
            var way_tags:Object = findWayTags();
            
            var way:Way = connection.createWay(way_tags, nodes, performAction);
            // Split any ways that cross the centre of the roundabout.
            for each (var w: Way in node.parentWays) {
                if (!w.endsWith(node))
                  performAction(new SplitWayAction(w, w.indexOfNode(node)));
            }
            doRelations(way); // Must be after the split above, and before the splits below.
            doJunctions(way);
            _createdWay = way;
            actionsDone = true;
            return UndoableAction.SUCCESS;
        }
        
        private function makeCircle():Array {
            // Pick a number of nodes vaguely in proportion to the size of circle
            // This should really be linear but someone will complain about huge numbers of nodes being created. 
            var num_nodes: int = Math.pow(radius, 1/2) * 1400;
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
        
        /** Find way tags to put on the new way, based on the highest rank of roads connected to it. */
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
        
        /** Locate intersections with any roads, and split and remove those inside the roundabout. */
        private function doJunctions(way: Way):void {
           
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
        
        /** Find on connected ways, and add any that belongs to at least two ways. Only deals with "route" relations atm. */
        private function doRelations(way: Way): void{
            var relcount: Object= {};
            for each (var w: Way in node.parentWays) {
                for each (var r: Relation in w.findParentRelationsOfType("route")) {
                    if (!relcount[r.id])
                       relcount[r.id]=0;
                    relcount[r.id]++;
                }
            }
            for (var rid: String in relcount) {
                if (relcount[rid] >= 2) {
                    connection.getRelation(new Number(rid)).insertMember(0, new RelationMember(way, "" /* ?! */), performAction);
                }
            }
        }

	}
}