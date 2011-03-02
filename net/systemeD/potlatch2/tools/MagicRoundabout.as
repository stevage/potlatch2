package net.systemeD.potlatch2.tools
{
    import net.systemeD.halcyon.connection.*;
    import net.systemeD.halcyon.connection.actions.MagicRoundaboutAction;
	public class MagicRoundabout
	{
		private var _action: MagicRoundaboutAction;
		/** Creates a roundabout, forms junctions, removes the internal ways, and sets tags. All in one sweet tool. 
		 * @param initNode The location that the roundabout will be centred around. Any ways connected to this node will be split.
		 * @param initRadius Radius of roundabout, in map coords.
		 * @param performAction The usual undo stack thing. */
		public function MagicRoundabout(node: Node, radius: Number, performAction:Function) {
			_action = new MagicRoundaboutAction(node, radius);
			performAction(_action);
		}
		
		/** Returns the way representing the created roundabout. Only call this after the action has actually been executed (not just queued). */
		public function get createdWay():Way {
			return _action.createdWay;
		}
	}
}