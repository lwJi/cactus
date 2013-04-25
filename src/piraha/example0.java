import edu.lsu.cct.piraha.*;

public class example0 {
    public static void main(String[] args) {
        // Allocate a grammar
        Grammar gram = new Grammar();

        // Compile the rules individually
        gram.compile("num","[0-9]+");
        gram.compile("expr","range=\\[{num}:{num}\\]");

        // Attempt a match
        // The matcher holds the parse tree in memory.
        String input = "range=[10:150]";
        Matcher  matcher = gram.matcher(input);
        if(matcher.matches()) {
            System.out.println("Match succeeded!");
            int v1,v2;

            Group group = matcher;
            Group ch = group.group(0);
            String s = ch.substring();
            v1 = Integer.parseInt(s);

            ch = group.group(1);
            s = ch.substring();
            v2 = Integer.parseInt(s);

            System.out.println("v1=" + v1 + ",v2=" + v2);
        } else {
            Near near = matcher.near();
            System.err.println("fail at pos=" + near.pos
                + ": found='" + input.charAt(near.pos)
                + "', expected=" + near.expected);
        }
    }
}

