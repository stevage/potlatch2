package net.systemeD.halcyon.connection.actions
{
	import net.systemeD.halcyon.connection.*;
	import net.systemeD.potlatch2.tools.MakeJunctions;

	/** Creates a roundabout, forms junctions, removes the internal ways, and sets tags. All in one sweet action.*/
	public class MagicRoundaboutAction extends CompositeUndoableAction
	{
        private var centre: Node;
        private var radius: Number;
        private var connection: Connection;
        protected var _createdWay: Way;
        public function get createdWay():Way { return _createdWay; }

		public function MagicRoundaboutAction(centre: Node, radius: Number)
		{
			super('Magic roundabout');
            this.centre = centre;
            this.radius = radius;
            connection = centre.connection;
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
            
            _createdWay = connection.createWay(way_tags, nodes, performAction);
            // Split any ways that cross the centre of the roundabout.
            for each (var w: Way in centre.parentWays) {
                if (!w.endsWith(centre))
                  performAction(new SplitWayAction(w, w.indexOfNode(centre)));
            }
            doRelations(_createdWay); // Must be after the split above, and before the splits below.
            doJunctions(_createdWay);
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
                   Node.latp2lat(centre.latp + Math.sin(a) * radius), // Use latp to get round circles
                   centre.lon + Math.cos(a) * radius,
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
            for each (var w: Way in centre.parentWays) {
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
            // Now delete any bits of ways that are inside the roundabout
            for each (var j: Node in junctions) {
                // split ways that cross our roundabout more than once.
                // (ways that cross just once don't need to be split - we'll just cut the extra nodes off.)
                var i: int = 0;
                while (i < j.parentWays.length) { // can't use for each, because we're adding to j.parentWays
                	var w: Way = j.parentWays[i];
                	i++;
                	if (w == _createdWay)
                	   continue; // don't split the roundabout!
                	if (w.getJunctionsWith(_createdWay).length > 1 ) {
                	   if (!w.endsWith(j)) {
                        // this way crosses our roundabout more than once - needs to be split.
                	       performAction(new SplitWayAction(w, w.indexOfNode(j)));
                	       i=0; // sometimes the new way is the first parentWay, so we have to start looking all over again.
                		} else if (w.length == 2)
                		    // a 2-node way that touches our circle twice is by definition "inside" it, but won't be caught
                		    // by our node-searching below.
                		    w.remove(performAction);
                		    
                	}
                }      
                // Our junction may have different parent ways now.
                for each (w in j.parentWays.concat(centre.parentWays)) {
                    // Iterate on every node of every way touched by our roundabout
                    if (w == _createdWay)
                       continue; // don't remove nodes from the roundabout itself...
                    var nodes:Array = w.getNodes();
                    for each (var wn: Node in nodes) {
                    	if (wn.hasParent(_createdWay))
                    	   continue;
                    	if (_createdWay.pointWithin(wn.lon, wn.lat)) {
                            // This node is inside our roundabout: destroy it.
                            wn.remove(performAction);
                    		
                    	}
                    }
                }
            }
        }
        
        /** Find on connected ways, and add any that belongs to at least two ways. Only deals with "route" relations atm. */
        private function doRelations(way: Way): void{
            var relcount: Object= {};
            for each (var w: Way in centre.parentWays) {
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