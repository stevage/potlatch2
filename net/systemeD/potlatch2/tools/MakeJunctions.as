package net.systemeD.potlatch2.tools {
    import net.systemeD.halcyon.connection.*;
    import net.systemeD.halcyon.connection.actions.MakeJunctionsAction;
	
	/** Tool that automatically creates junctions between the given way and any ways that it crosses. Can also be used
	 * internally by other functions to create junctions and return them as a list. */
	 
	 public class MakeJunctions
    {
        private var _action: MakeJunctionsAction;
        /** Creates junction nodes every where the way crosses any other way. 
         * @param way The way to form junctions for.
         * @param onlyTransportTags If true, only form junctions against highways, railways etc.
         * @param performAction The usual undo stack thing. */
        public function MakeJunctions(way: Way, onlyTransportTags: Boolean, performAction:Function) {
            _action = new MakeJunctionsAction(way, onlyTransportTags);
            performAction(_action);
        }
        
        /** Returns the created junctions. Only call this after the action has actually been executed (not just queued). */
        public function get getComputedJunctions():Array {
            return _action.getComputedJunctions();
        }
    }
}
