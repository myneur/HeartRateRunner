
//! A circular queue core by @author Konrad Paumann, math methods by Indrik myneur
class DataQueue {
    //! the data array.
    var data;
    var maxSize = 0;
    var pos = 0;

    //! precondition: size has to be >= 2
    function initialize(arraySize) {
        data = new [arraySize];
        maxSize = arraySize;
    }

    //! Add an element to the queue.
    function add(element) {
        data[pos] = element;
        pos = (pos + 1) % maxSize;
        return pos;
    }

    function average() {
        var sum = 0;
        var size = 0;
        for (var i = 0; i < maxSize; i++) {
            if (data[i] != null) {
                sum = sum + data[i];
                size++;
            }
        }
        if (size == 0) {
            return null;
        } else {
            return (sum / size.toFloat());
        }
    }

    function max() {
        var max = null;
        for (var i = 0; i < maxSize; i++) {
            if (data[i] == null) {
                continue;
            }
            if (max == null || data[i] > max) {
                max = data[i];
            }
        }
        return max;
    }

    function min() {
        var min = null;
        for (var i = 0; i < maxSize; i++) {
            if (data[i] == null) {
                continue;
            }
            if (min == null || data[i] < min) {
                min = data[i];
            }
        }
        return min;
    }

    function prev(i) {
        if (i >= maxSize) {
            return null;
        }
        return data[(maxSize + pos - i - 1) % maxSize];
    }
}